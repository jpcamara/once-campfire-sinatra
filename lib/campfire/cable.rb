require "async"
require "async/queue"
require "async/websocket/adapters/rack"
require "json"

module Campfire
  # The Action Cable server protocol (actioncable-v1-json) and Campfire's channels.
  module Cable
    PROTOCOLS = %w[ actioncable-v1-json actioncable-unsupported ].freeze
    PING_INTERVAL = 3
    CONNECTION_TTL = 60

    @connections = {}
    @started = false

    class << self
      attr_reader :connections

      # A Rack endpoint for /cable.
      def call(env)
        start_process_tasks
        user = authenticate(env)

        Async::WebSocket::Adapters::Rack.open(env, protocols: PROTOCOLS) do |websocket|
          if user
            Connection.new(websocket, user, env).run
          else
            websocket.write(Protocol::WebSocket::TextMessage.generate(%({"type":"disconnect","reason":"unauthorized","reconnect":false})))
            websocket.flush
            websocket.close
          end
        end || [ 404, {}, [] ]
      end

      def authenticate(env)
        runtime.db.check_for_changes
        cookies = Rack::Utils.parse_cookies(env)
        token = cookies["session_token"] && runtime.secrets.verify_cookie("session_token", cookies["session_token"])
        session = token && runtime.repo.session_by_token(token)
        session && runtime.repo.user(session.user_id)
      end

      def runtime = App.runtime

      # Per process: the Redis listener and the ping timer, as root tasks of this process's reactor.
      def start_process_tasks
        return if @started
        @started = true
        Fiber.scheduler.async { Broadcasts.listen }
        Fiber.scheduler.async do
          loop do
            sleep PING_INTERVAL
            frame = %({"type":"ping","message":#{Time.now.to_i}})
            @connections.each_key { it.enqueue(frame) }
          end
        end
      end
    end

    class Connection
      attr_reader :user

      def initialize(websocket, user, env)
        @websocket, @user, @env = websocket, user, env
        @subscriptions = {}
        @outbox = Async::Queue.new
      end

      def run
        Cable.connections[self] = true
        writer = Async { drain }
        enqueue(%({"type":"welcome"}))
        while (message = @websocket.read)
          receive(message.to_str)
        end
      rescue Protocol::WebSocket::ClosedError, EOFError, Errno::ECONNRESET, Errno::EPIPE, IOError
        # The client went away.
      ensure
        Cable.connections.delete(self)
        @subscriptions.each_value { it.unsubscribed rescue nil }
        @subscriptions.clear
        writer&.stop
      end

      def enqueue(frame)
        @outbox.enqueue(frame)
      end

      # ActionCable::Connection::Base#close(reason: "remote", reconnect:)
      def disconnect(reconnect:)
        enqueue(%({"type":"disconnect","reason":"remote","reconnect":#{reconnect}}))
        enqueue(:close)
      end

      private
        def drain
          while (frame = @outbox.dequeue)
            if frame == :close
              @websocket.flush
              break @websocket.close
            end
            @websocket.write(Protocol::WebSocket::TextMessage.new(frame))
            @websocket.flush if @outbox.empty?
          end
        rescue Protocol::WebSocket::ClosedError, EOFError, Errno::ECONNRESET, Errno::EPIPE, IOError
          @websocket.close rescue nil
        end

        def receive(text)
          Cable.runtime.db.check_for_changes
          data = JSON.parse(text)
          identifier = data["identifier"]
          case data["command"]
          when "subscribe" then subscribe(identifier)
          when "unsubscribe" then @subscriptions.delete(identifier)&.unsubscribed
          when "message"
            subscription = @subscriptions[identifier]
            subscription&.perform(JSON.parse(data["data"].to_s))
          end
        rescue JSON::ParserError
          nil
        rescue => error
          # One failing command (a broadcast that can't reach Redis, say) doesn't drop the connection.
          warn "cable command failed: #{error.class}: #{error.message}"
        end

        def subscribe(identifier)
          return if @subscriptions.key?(identifier)
          params = JSON.parse(identifier.to_s)
          channel = Channels.for(params["channel"])
          subscription = channel&.new(self, identifier, params)

          if subscription&.subscribe
            @subscriptions[identifier] = subscription
            enqueue(%({"identifier":#{JSON.generate(identifier)},"type":"confirm_subscription"}))
            subscription.after_confirm
          else
            enqueue(%({"identifier":#{JSON.generate(identifier)},"type":"reject_subscription"}))
          end
        rescue JSON::ParserError
          enqueue(%({"identifier":#{JSON.generate(identifier)},"type":"reject_subscription"}))
        end
    end

    module Channels
      def self.for(name)
        {
          "Turbo::StreamsChannel" => TurboStreams,
          "RoomMessagesChannel" => RoomMessages,
          "PresenceChannel" => Presence,
          "TypingNotificationsChannel" => TypingNotifications,
          "UnreadRoomsChannel" => UnreadRooms,
          "ReadRoomsChannel" => ReadRooms,
          "HeartbeatChannel" => Heartbeat
        }[name]
      end

      class Base
        attr_reader :identifier

        def initialize(connection, identifier, params)
          @connection, @identifier, @params = connection, identifier, params
          @streams = []
        end

        def user = @connection.user
        def runtime = App.runtime
        def repo = runtime.repo

        def subscribe = true
        def after_confirm; end
        def perform(data); end

        def unsubscribed
          @streams.each { Broadcasts.unsubscribe(it, self) }
          @streams.clear
        end

        def transmit_frame(frame)
          @connection.enqueue(frame)
        end

        private
          def stream_from(name)
            @streams << name
            Broadcasts.subscribe(name, self)
          end

          def user_room(room_id)
            room_id && repo.user_room(user.id, room_id.to_i)
          end
      end

      class Heartbeat < Base; end

      class TurboStreams < Base
        def subscribe
          name = runtime.secrets.verified_stream_name(@params["signed_stream_name"].to_s)
          # config/initializers/turbo_streams_authorization.rb: room message streams only through RoomMessagesChannel
          return false if name.nil? || name.split(":", 2)[1] == "messages"
          stream_from(name)
        end
      end

      class RoomMessages < Base
        def subscribe
          name = runtime.secrets.verified_stream_name(@params["signed_stream_name"].to_s)
          return false unless name
          gid_param, suffix = name.split(":", 2)
          return false unless suffix == "messages" && (room_id = room_id_from_gid(gid_param)) && user_room(room_id)
          stream_from(name)
        end

        private
          def room_id_from_gid(param)
            gid = Base64.urlsafe_decode64(param) rescue nil
            gid&.match(%r{\Agid://campfire/Rooms::(?:Open|Closed|Direct)/(\d+)\z})&.[](1)
          end
      end

      class RoomChannel < Base
        def subscribe
          @room = user_room(@params["room_id"])
          return false unless @room
          stream_from("#{self.class::PREFIX}:#{RailsCompat.gid_param(@room.type, @room.id)}")
        end
      end

      class Presence < RoomChannel
        PREFIX = "presence"

        def after_confirm
          Memberships.present(runtime, user.id, @room.id)
          Broadcasts.json("user_#{user.id}_reads", { room_id: @room.id })
        end

        def unsubscribed
          super
          Memberships.disconnected(runtime, user.id, @room.id) if @room
        end

        def perform(data)
          Memberships.refresh_connection(runtime, user.id, @room.id) if data["action"] == "refresh"
        end
      end

      class TypingNotifications < RoomChannel
        PREFIX = "typing_notifications"

        def perform(data)
          action = data["action"]
          return unless %w[ start stop ].include?(action)
          Broadcasts.json("#{PREFIX}:#{RailsCompat.gid_param(@room.type, @room.id)}", { action: action, user: { id: user.id, name: user.name } })
        end
      end

      class UnreadRooms < Base
        def subscribe = stream_from("user_#{user.id}_unreads")
      end

      class ReadRooms < Base
        def subscribe = stream_from("user_#{user.id}_reads")
      end
    end
  end

  # Membership::Connectable
  module Memberships
    module_function

    def present(runtime, user_id, room_id)
      runtime.db.transaction do |w|
        connected_at, connections = w.row("SELECT connected_at, connections FROM memberships WHERE user_id = ? AND room_id = ?", user_id, room_id)
        count = connected?(connected_at) ? connections + 1 : 1
        w.run("UPDATE memberships SET connections = ?, connected_at = ?, unread_at = NULL WHERE user_id = ? AND room_id = ?",
          count, TimeFormat.now_text, user_id, room_id)
      end
    end

    def disconnected(runtime, user_id, room_id)
      runtime.db.transaction do |w|
        connected_at, connections = w.row("SELECT connected_at, connections FROM memberships WHERE user_id = ? AND room_id = ?", user_id, room_id)
        next if connections.nil?
        now = TimeFormat.now_text
        if connected?(connected_at)
          connections -= 1
          w.run("UPDATE memberships SET connections = ?, updated_at = ? WHERE user_id = ? AND room_id = ?", connections, now, user_id, room_id)
        else
          connections = 0
          w.run("UPDATE memberships SET connections = 0, updated_at = ? WHERE user_id = ? AND room_id = ?", now, user_id, room_id)
        end
        w.run("UPDATE memberships SET connected_at = NULL, updated_at = ? WHERE user_id = ? AND room_id = ?", now, user_id, room_id) if connections < 1
      end
    end

    def refresh_connection(runtime, user_id, room_id)
      runtime.db.transaction do |w|
        connected_at, connections = w.row("SELECT connected_at, connections FROM memberships WHERE user_id = ? AND room_id = ?", user_id, room_id)
        next if connections.nil?
        now = TimeFormat.now_text
        unless connected?(connected_at)
          w.run("UPDATE memberships SET connections = 1, updated_at = ? WHERE user_id = ? AND room_id = ?", now, user_id, room_id)
        end
        w.run("UPDATE memberships SET connected_at = ?, updated_at = ? WHERE user_id = ? AND room_id = ?", now, now, user_id, room_id)
      end
    end

    def connected?(connected_at)
      connected_at && TimeFormat.parse(connected_at) >= Time.now - Cable::CONNECTION_TTL
    end
  end
end
