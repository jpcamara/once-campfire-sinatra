require "redis-client"
require "json"

module Campfire
  # Action Cable broadcasting across Falcon's worker processes. Every broadcast goes through one
  # Redis channel; each process listens and hands the message to its own subscribers. Within a
  # process, subscriptions are registered per stream name.
  module Broadcasts
    CHANNEL = "campfire:broadcasts"

    @streams = Hash.new { |hash, key| hash[key] = [] }
    @mutex = Mutex.new

    class << self
      # A Turbo Stream broadcast: Action Cable JSON-encodes the HTML string.
      def turbo_stream(stream, html)
        raw(stream, JSON.generate(html))
      end

      # `payload` is the message's JSON, as ActionCable.server.broadcast(..., coder: nil) sends it.
      def raw(stream, payload)
        publisher.call("PUBLISH", CHANNEL, "#{stream}\0#{payload}")
      end

      def redis_call(*command)
        publisher.call(*command)
      end

      def json(stream, object)
        raw(stream, JSON.generate(object))
      end

      def subscribe(stream, subscription)
        @streams[stream] << subscription
      end

      def unsubscribe(stream, subscription)
        list = @streams[stream]
        list.delete(subscription)
        @streams.delete(stream) if list.empty?
      end

      # Runs in this process's reactor for the life of the process.
      def listen
        config = RedisClient.config(url: url, read_timeout: nil)
        loop do
          connection = config.new_client.pubsub
          connection.call("SUBSCRIBE", CHANNEL)
          loop do
            event = connection.next_event or next # nil when a read times out
            next unless event[0] == "message"
            stream, payload = event[2].dup.force_encoding(Encoding::UTF_8).split("\0", 2)
            begin
              deliver(stream, payload)
            rescue => error
              warn "broadcast delivery failed: #{error.class}: #{error.message}"
            end
          end
        rescue RedisClient::Error, IOError, SystemCallError => error
          warn "broadcast listener: #{error.class}: #{error.message}"
          sleep 0.5
        ensure
          connection&.close
        end
      end

      def deliver(stream, payload)
        subscribers = @streams[stream]
        return @streams.delete(stream) if subscribers.empty?

        frames = {}
        subscribers.dup.each do |subscription|
          frame = frames[subscription.identifier] ||= %({"identifier":#{JSON.generate(subscription.identifier)},"message":#{payload}})
          subscription.transmit_frame(frame)
        end
      end

      def url
        ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") # bin/start runs Redis there unless REDIS_URL says otherwise
      end

      private
        # One publishing connection per process; RedisClient is safe across fibers on one thread
        # only when calls don't interleave, so publishes take a lock.
        def publisher
          @publisher_lock ||= Mutex.new
          @publisher ||= RedisClient.config(url: url).new_client
          Publisher.new(@publisher, @publisher_lock)
        end
    end

    Publisher = Data.define(:client, :lock) do
      def call(*command)
        lock.synchronize { client.call(*command) }
      end
    end
  end
end
