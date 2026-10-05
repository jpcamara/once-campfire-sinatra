require "rqrcode"

module Campfire
  # Users::AvatarsController and Accounts::LogosController
  module Avatars
    SVG = <<~SVG.freeze
      <svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
        viewBox="0 0 512 512" class="avatar" aria-hidden="true">
        <defs>
          <clipPath id="porthole">
            <circle cx="50%%" cy="50%%" r="50%%" />
          </clipPath>
        </defs>

        <g>
          <rect width="100%%" height="100%%" rx="50" fill="%s" />

          <text x="50%%" y="50%%" fill="#FFFFFF"
            text-anchor="middle" dy="0.35em"
            %s
            font-family="-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif"
            font-size="230"
            font-weight="800"
            letter-spacing="-5">
            %s
          </text>
        </g>
      </svg>
    SVG

    module_function

    def show(app, token)
      runtime = app.runtime
      user_id = runtime.secrets.find_signed_id(token, "user/avatar")
      user = user_id && runtime.repo.user(user_id)
      app.halt 404, "" unless user

      app.etag Digest::MD5.hexdigest("users/#{user.id}-#{user.updated_at}"), kind: :weak
      app.headers "Cache-Control" => "max-age=1800, public, stale-while-revalidate=604800", "Vary" => "Accept"

      if (variant = avatar_variant(runtime, user))
        app.send_file Storage.path_for(variant.key), type: "image/webp", disposition: "inline"
      elsif user.bot?
        app.send_file File.join(ROOT, "public/default-bot-avatar.svg"), type: "image/svg+xml", disposition: "inline"
      else
        app.headers "Content-Type" => "image/svg+xml; charset=utf-8"
        initials = user.initials
        length = initials.size >= 3 ? 'textLength="85%" lengthAdjust="spacingAndGlyphs"' : ""
        format(SVG, View::AVATAR_COLORS[Zlib.crc32(user.to_param) % View::AVATAR_COLORS.size], length, HTML.h(initials))
      end
    end

    # User::Avatar#avatar_variant: the 512px webp square, built on first request.
    def avatar_variant(runtime, user)
      blob = runtime.repo.attachment_blob("User", user.id, "avatar") or return nil
      return nil unless Attachments.variable?(blob)
      Uploads.variant_blob(Context.new(runtime), blob, { "resize_to_limit" => [ 512, 512 ], "format" => "webp" })
    end

    def account_logo(app)
      runtime = app.runtime
      account = runtime.account
      app.etag Digest::MD5.hexdigest("accounts/#{account.id}-#{account.updated_at}"), kind: :weak
      app.headers "Cache-Control" => "max-age=300, public, stale-while-revalidate=604800", "Vary" => "Accept"
      small = app.params["size"] == "small"
      blob = runtime.repo.attachment_blob("Account", account.id, "logo")
      if blob && Attachments.variable?(blob)
        size = small ? 192 : 512
        variant = Uploads.variant_blob(Context.new(runtime), blob, { "resize_to_limit" => [ size, size ], "format" => "png" })
        app.send_file Storage.path_for(variant.key), type: "image/png", disposition: "inline"
      else
        app.send_file File.join(ROOT, "public/logos", small ? "app-icon-192.png" : "app-icon.png"), type: "image/png", disposition: "inline"
      end
    end
  end

  # The bits of a request context the data helpers need, for work outside a request.
  Context = Data.define(:runtime) do
    def db = runtime.db
    def repo = runtime.repo
  end

  module Searches
    module_function

    # Search.record: find_or_create_by(query:).touch, then keep the ten most recent.
    def record(ctx, user, query)
      return if query.to_s.empty?
      now = TimeFormat.now_text
      ctx.db.transaction do |w|
        if (id = w.value("SELECT id FROM searches WHERE user_id = ? AND query = ? LIMIT 1", user.id, query))
          w.run("UPDATE searches SET updated_at = ? WHERE id = ?", now, id)
        else
          w.run("INSERT INTO searches (created_at, query, updated_at, user_id) VALUES (?, ?, ?, ?)", now, query, now, user.id)
          w.run(<<~SQL, user.id, user.id)
            DELETE FROM searches WHERE user_id = ? AND id NOT IN (SELECT id FROM searches WHERE user_id = ? ORDER BY updated_at DESC LIMIT 10)
          SQL
        end
      end
    end
  end

  module QrCodes
    module_function

    def show(app, id)
      url = Base64.urlsafe_decode64(id)
      app.headers "Cache-Control" => "max-age=31536000, public"
      app.headers "Content-Type" => "image/svg+xml; charset=utf-8"
      RQRCode::QRCode.new(url).as_svg(viewbox: true, fill: :white, color: :black)
    end
  end

  # Background work, like the Rust port's in-process queues: a few threads per process, each with
  # its own database connections.
  module Jobs
    @queue = Thread::Queue.new
    @threads = []

    class << self
      def later(&block)
        start
        @queue << block
      end

      def runtime
        Thread.current[:campfire_job_runtime] ||= JobRuntime.new
      end

      private
        def start
          return if @started == Process.pid
          @started = Process.pid
          @threads = Array.new(ENV.fetch("JOB_CONCURRENCY", 2).to_i.clamp(1, 16)) do
            Thread.new do
              loop do
                job = @queue.pop
                begin
                  job.call
                rescue Exception => error
                  warn "job failed: #{error.class}: #{error.message}"
                end
              end
            end
          end
        end
    end

    # A Runtime for job threads: shares secrets and settings, owns its database connections.
    class JobRuntime < SimpleDelegator
      attr_reader :db, :repo

      def initialize
        super(App.runtime)
        @db = DB.new
        @repo = Repo.new(@db)
      end
    end
  end

  # Room::MessagePusher over Push::Subscription: payloads go only to permitted push services.
  module Push
    PERMITTED_HOSTS = %w[ jmt17.google.com fcm.googleapis.com updates.push.services.mozilla.com web.push.apple.com notify.windows.com ].freeze

    module_function

    def deliver_for_message(_runtime, room_id, message_id)
      runtime = Jobs.runtime
      repo = runtime.repo
      room = repo.room(room_id) or return
      row = runtime.db.row("SELECT #{Message.columns} FROM messages WHERE id = ?", message_id) or return
      message = Message.new(*row)
      creator = repo.user(message.creator_id)
      body = repo.bodies([ message.id ])[message.id]
      attachment = repo.message_attachments([ message.id ])[message.id]
      plain = Messages.plain_text_body(Context.new(runtime), body, attachment)
      payload =
        if room.direct?
          { title: creator.name, body: plain, path: "/rooms/#{room.id}" }
        else
          { title: room.name, body: "#{creator.name}: #{plain}", path: "/rooms/#{room.id}" }
        end

      cutoff = (Time.now.utc - Cable::CONNECTION_TTL).strftime("%Y-%m-%d %H:%M:%S.%6N")
      base = <<~SQL
        SELECT push_subscriptions.id, push_subscriptions.endpoint, push_subscriptions.p256dh_key, push_subscriptions.auth_key, push_subscriptions.user_id
        FROM push_subscriptions INNER JOIN users ON users.id = push_subscriptions.user_id INNER JOIN memberships ON memberships.user_id = users.id
        WHERE memberships.involvement != 'invisible' AND (memberships.connected_at IS NULL OR memberships.connected_at < ?)
        AND memberships.room_id = ? AND memberships.user_id != ?
      SQL
      everything = runtime.db.rows("#{base} AND memberships.involvement = 'everything'", cutoff, room.id, creator.id)
      mentionee_ids = Mentions.user_ids(body.to_s)
      mentions = mentionee_ids.empty? ? [] :
        runtime.db.rows("#{base} AND memberships.involvement = 'mentions' AND push_subscriptions.user_id IN (#{DB.in_list(mentionee_ids.size)})", cutoff, room.id, creator.id, *mentionee_ids)

      (everything + mentions).each do |id, endpoint, p256dh, auth, user_id|
        next unless permitted?(endpoint)
        badge = runtime.db.value("SELECT COUNT(*) FROM memberships WHERE user_id = ? AND unread_at IS NOT NULL", user_id)
        deliver(runtime, id, endpoint, p256dh, auth, payload, badge)
      end
    end

    def permitted?(endpoint)
      uri = URI.parse(endpoint.to_s)
      host = uri.host.to_s.downcase
      uri.scheme == "https" && uri.port == 443 && PERMITTED_HOSTS.any? { host == it || host.end_with?(".#{it}") }
    rescue URI::InvalidURIError
      false
    end

    def deliver(runtime, id, endpoint, p256dh, auth, payload, badge)
      require "web-push"
      message = JSON.generate(title: payload[:title], options: { body: payload[:body], icon: "/account/logo", data: { path: payload[:path], badge: badge } })
      WebPush.payload_send(message: message, endpoint: endpoint, p256dh: p256dh, auth: auth, urgency: "high",
        vapid: { subject: "mailto:support@37signals.com", public_key: ENV["VAPID_PUBLIC_KEY"], private_key: ENV["VAPID_PRIVATE_KEY"] })
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
      runtime.db.transaction { |w| w.run("DELETE FROM push_subscriptions WHERE id = ?", id) }
    rescue => error
      warn "push failed: #{error.class}: #{error.message}"
    end
  end

  # Message::Mentionee: the users a body mentions, from their attachment sgids.
  module Mentions
    module_function

    def user_ids(body)
      return [] unless body.include?("action-text-attachment")
      RichText.fragment(body).css(RichText::ATTACHMENT_TAG).filter_map { GlobalIds.user_id_from_sgid(it["sgid"]) }.uniq
    end
  end

  module GlobalIds
    module_function

    # lib/rails_ext/action_text_attachables.rb: mentions are located without checking the signature.
    def user_id_from_sgid(sgid)
      message = sgid.to_s.split("--").first or return nil
      decoded = (Base64.strict_decode64(message) rescue Base64.urlsafe_decode64(message)) rescue (return nil)
      envelope = JSON.parse(decoded)["_rails"] rescue (return nil)
      gid = if envelope["data"]
        envelope["data"]
      elsif envelope["message"]
        Base64.decode64(envelope["message"])[%r{gid://campfire/[^/]+/\d+}]
      end
      gid.to_s[%r{\Agid://campfire/User/(\d+)}, 1]&.to_i
    end
  end

  # Bot webhooks: the bots a message is for, posted the message as JSON from a job.
  module Webhooks
    module_function

    def deliver_later(runtime, room, message)
      body = runtime.repo.bodies([ message.id ])[message.id].to_s
      bot_ids =
        if room.direct?
          runtime.db.rows("SELECT users.id FROM users INNER JOIN memberships ON users.id = memberships.user_id WHERE memberships.room_id = ? AND users.status = 0 AND users.role = 2", room.id).map(&:first)
        else
          ids = Mentions.user_ids(body)
          ids.empty? ? [] : runtime.db.rows("SELECT users.id FROM users INNER JOIN memberships ON users.id = memberships.user_id WHERE memberships.room_id = ? AND users.id IN (#{DB.in_list(ids.size)}) AND users.status = 0 AND users.role = 2", room.id, *ids).map(&:first)
        end
      (bot_ids - [ message.creator_id ]).each { |bot_id| Jobs.later { Bots.deliver(bot_id, message.id) } }
    end
  end
end

module Campfire
  # Bot::WebhookJob: posts the message to the bot's webhook. Replies are posted back to the room
  # by the bot (see Bots.reply), as Webhook#deliver does.
  module Bots
    ENDPOINT_TIMEOUT = 7

    module_function

    def deliver(bot_id, message_id)
      runtime = Jobs.runtime
      url = runtime.db.value("SELECT url FROM webhooks WHERE user_id = ? LIMIT 1", bot_id) or return
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = http.read_timeout = ENDPOINT_TIMEOUT
      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
      request.body = payload(runtime, message_id)
      http.request(request)
    rescue => error
      warn "webhook failed: #{error.class}: #{error.message}"
    end

    def payload(runtime, message_id)
      row = runtime.db.row("SELECT #{Message.columns} FROM messages WHERE id = ?", message_id)
      message = Message.new(*row)
      user = runtime.repo.user(message.creator_id)
      room = runtime.repo.room(message.room_id)
      body = runtime.repo.bodies([ message.id ])[message.id].to_s
      JSON.generate(
        user: { id: user.id, name: user.name },
        room: { id: room.id, name: room.name, path: "/rooms/#{room.id}/bot/messages" },
        message: { id: message.id, body: { html: body, plain: PlainText.convert(body) }, path: "/rooms/#{room.id}/@#{message.id}" })
    end
  end
end

module Campfire
  module Maintenance
    module_function

    # What the Rails app does at boot: the database exists (db:prepare) and no membership still
    # counts connections from before the restart (Membership.disconnect_all in config/puma.rb).
    def boot
      db = DB.new
      cutoff = (Time.now.utc - Cable::CONNECTION_TTL).strftime("%Y-%m-%d %H:%M:%S.%6N")
      db.transaction do |w|
        w.run("UPDATE memberships SET connected_at = NULL, connections = 0, updated_at = ? WHERE connected_at >= ?", TimeFormat.now_text, cutoff)
      end
    end
  end
end
