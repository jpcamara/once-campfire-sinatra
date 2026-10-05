require "sinatra/base"
require "securerandom"
require "bcrypt"
require "uri"

module Campfire
  ROOT = File.expand_path("../..", __dir__)

  # Process-wide state shared by requests: the database, secrets and caches.
  class Runtime
    attr_reader :db, :repo, :secrets, :fragment_cache, :vapid_public_key, :app_version, :git_revision

    def initialize
      @db = DB.new
      @repo = Repo.new(@db)
      @secrets = RailsCompat::Secrets.new(ENV.fetch("SECRET_KEY_BASE"))
      @fragment_cache = FragmentCache.new(ENV.fetch("FRAGMENT_CACHE_SIZE", 5_000).to_i)
      @vapid_public_key = ENV["VAPID_PUBLIC_KEY"]
      @app_version = ENV["APP_VERSION"].to_s.empty? ? (ENV["GIT_REVISION"].to_s.empty? ? "0" : ENV["GIT_REVISION"]) : ENV["APP_VERSION"]
      @git_revision = ENV["GIT_REVISION"]
      @avatar_tokens = {}
    end

    def account
      @repo.account
    end

    def account_logo_attached?
      !@repo.attachment_blob("Account", account.id, "logo").nil?
    end

    def avatar_token(user_id)
      @avatar_tokens[user_id] ||= @secrets.signed_id(user_id, "user/avatar").freeze
    end

    def all_emoji?(text)
      text.match?(/\A(\p{Emoji_Presentation}|\p{Extended_Pictographic}|️)+\z/u)
    end

    def blob_path(blob, disposition: nil)
      Storage.blob_path(self, blob, disposition: disposition)
    end
  end

  module Tokens
    BASE58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".chars.freeze

    BASE36 = [ *"0".."9", *"a".."z" ].freeze

    # ActiveSupport's SecureRandom.base58, as has_secure_token uses it.
    def self.base58(length)
      Array.new(length) { BASE58[SecureRandom.random_number(58)] }.join
    end

    # SecureRandom.base36, as Active Storage generates blob keys.
    def self.base36(length)
      Array.new(length) { BASE36[SecureRandom.random_number(36)] }.join
    end
  end

  # A bounded per-process cache for rendered fragments, evicting the oldest entries first.
  class FragmentCache
    def initialize(limit)
      @limit = limit
      @entries = {}
    end

    def key?(key)
      @entries.key?(key)
    end

    def fetch(key)
      if (value = @entries.delete(key))
        @entries[key] = value
      else
        value = yield
        @entries[key] = value
        @entries.delete(@entries.first[0]) while @entries.size > @limit
        value
      end
    end
  end

  class App < Sinatra::Base
    PERMANENT_YEARS = 20
    SESSION_REFRESH = 3600

    set :root, ROOT
    set :views, File.join(ROOT, "views")
    set :public_folder, nil
    set :static, false
    set :show_exceptions, false
    set :raise_errors, false
    set :logging, nil
    set :protection, false
    set :method_override, true
    disable :sessions

    def self.runtime
      @runtime ||= Runtime.new
    end

    def runtime = self.class.runtime
    def repo = runtime.repo
    def db = runtime.db
    def secrets = runtime.secrets

    SECURITY_HEADERS = { "X-Frame-Options" => "SAMEORIGIN", "X-XSS-Protection" => "0", "X-Content-Type-Options" => "nosniff",
      "X-Permitted-Cross-Domain-Policies" => "none", "Referrer-Policy" => "strict-origin-when-cross-origin" }.freeze

    # ActionDispatch's default headers on every controller response, and ApplicationController's
    # VersionHeaders (a before_action after authentication: see require_authentication!).
    before do
      headers SECURITY_HEADERS
      headers "X-Version" => runtime.app_version, "X-Rev" => runtime.git_revision.to_s
    end

    # ApplicationController's AllowBrowser and BlockBannedRequests, ahead of authentication.
    before do
      next if request.path_info.start_with?("/rails/active_storage", "/up")
      halt render_incompatible_browser if Browsers.blocked?(request.user_agent)
      halt 429, "" if !(request.get? || request.head?) && db.value("SELECT 1 FROM bans WHERE ip_address = ? LIMIT 1", request.ip)
    end

    # ---- Health

    # Rails::HealthController: not an ApplicationController, so no version headers.
    get "/up" do
      without_version_headers
      headers "Cache-Control" => "max-age=0, private, must-revalidate", "Content-Type" => "text/html; charset=utf-8"
      %(<!DOCTYPE html><html><body style="background-color: green"></body></html>)
    end

    # ---- Static pages from public/ (Rails' public file server)

    get %r{/(404|422|500|502)\.html|/robots\.txt} do
      path = File.join(ROOT, "public", request.path_info)
      without_security_headers
      without_version_headers
      headers "Cache-Control" => "public, max-age=2592000", "Last-Modified" => File.mtime(path).httpdate,
        "Content-Type" => request.path_info.end_with?(".txt") ? "text/plain" : "text/html"
      File.read(path)
    end

    # ---- Sessions

    get "/session/new" do
      # SessionsController#ensure_user_exists
      return redirect(url_for("/first_run")) unless db.value("SELECT 1 FROM users LIMIT 1")
      render_page(:sessions_new, page_title: "Sign in", head: %(<meta name="turbo-visit-control" content="reload">), email_address: params["email_address"])
    end

    post "/session" do
      verify_same_origin!
      return render_sign_in_rejection(429) if RateLimit.exceeded?("sessions:#{request.ip}", limit: 10, within: 180)
      user = repo.active_user_by_email(params["email_address"].to_s)
      if user && user.password_digest && BCrypt::Password.new(user.password_digest) == params["password"].to_s
        start_new_session_for(user)
        redirect_after_authentication
      else
        render_sign_in_rejection(401)
      end
    end

    # ---- First run, joining, transfers

    get "/first_run" do
      return redirect(url_for("/")) if runtime.account
      render_page(:first_runs_show, page_title: "Set up Campfire", body_class: "signup")
    end

    post "/first_run" do
      verify_same_origin!
      return redirect(url_for("/")) if runtime.account
      user = Users.first_run(self, params["user"] || {})
      start_new_session_for(user)
      redirect url_for("/")
    end

    get "/join/:join_code" do
      return redirect(url_for("/")) if restore_authentication
      halt 404, "" unless runtime.account.join_code == params["join_code"]
      view = build_view(join_code: params["join_code"])
      render_layout(view, page_title: "Sign up", body_class: "signup", nav: view.tpl_users_new_nav, main: view.tpl_users_new)
    end

    post "/join/:join_code" do
      verify_same_origin!
      return redirect(url_for("/")) if restore_authentication
      halt 404, "" unless runtime.account.join_code == params["join_code"]
      attributes = params["user"] || {}
      if (user = Users.create(self, attributes))
        start_new_session_for(user)
        redirect url_for("/")
      else
        redirect url_for("/session/new?#{URI.encode_www_form(email_address: attributes["email_address"])}")
      end
    end

    get "/session/transfers/:id" do
      view = build_view(request_path: request.path)
      render_layout(view, main: view.tpl_sessions_transfer)
    end

    put "/session/transfers/:id" do
      verify_same_origin!
      user_id = secrets.find_signed_id(params["id"], "user/transfer")
      user = user_id && repo.user(user_id)
      halt 400, "" unless user&.active?
      start_new_session_for(user)
      redirect_after_authentication
    end

    delete "/session" do
      verify_same_origin!
      require_authentication!
      db.transaction { |w| w.run("DELETE FROM sessions WHERE id = ?", @session.id) }
      response.delete_cookie("session_token", path: "/")
      response.delete_cookie("_campfire_session", path: "/")
      redirect url_for("/")
    end

    # ---- Rooms

    get "/" do
      require_authentication!
      room = last_room_visited
      room ? redirect(url_for("/rooms/#{room.id}")) : render_welcome
    end

    get "/rooms" do
      require_authentication!
      room = repo.user_last_room(current_user.id)
      redirect url_for("/rooms/#{room.id}")
    end

    get %r{/rooms/(\d+)(?:/@(\d+))?} do |room_id, message_id|
      require_authentication!
      room = repo.user_room(current_user.id, room_id.to_i)
      return redirect_with_alert("/", "Room not found or inaccessible") unless room

      remember_last_room_visited(room)
      messages = find_room_messages(room, message_id)
      render_room(room, messages)
    end

    get %r{/rooms/(\d+)/messages} do |room_id|
      require_authentication!
      room = room_scoped!(room_id)
      messages =
        if (before = params["before"]).to_s != ""
          anchor = repo.room_message(room.id, before.to_i) or halt 404
          repo.page_before(room.id, anchor.created_at)
        elsif (after = params["after"]).to_s != ""
          anchor = repo.room_message(room.id, after.to_i) or halt 404
          repo.page_after(room.id, anchor.created_at)
        else
          repo.last_page(room.id)
        end

      if messages.empty?
        headers "Cache-Control" => "no-cache"
        status 204
        return ""
      end

      etag_for_messages(messages)
      # fresh_when @messages: the newest updated_at is the Last-Modified.
      headers "Last-Modified" => messages.map { TimeFormat.parse(it.updated_at) }.max.httpdate
      html_headers
      messages_html(messages)
    end

    post %r{/rooms/(\d+)/messages} do |room_id|
      verify_same_origin!
      require_authentication!
      membership = repo.membership(current_user.id, room_id.to_i)
      return render_room_not_found unless membership

      room = repo.room(membership.room_id)
      message = Messages.create(self, room: room, creator: current_user, params: params["message"] || {})
      view = message_views([ message ]).first
      Messages.after_create(self, room, message, view)

      html_headers("text/vnd.turbo-stream.html")
      %(<turbo-stream action="append" target="messages_#{room.param_key}_#{room.id}"><template>#{build_view.render_message_cached(view)}</template></turbo-stream>)
    end

    # ---- Room settings: open, closed and direct rooms

    get %r{/rooms/(opens|closeds)/new} do |kind|
      require_authentication!
      halt 403, "" unless can_create_rooms?
      render_room_settings(kind.chomp("s"), nil)
    end

    get %r{/rooms/(opens|closeds)/(\d+)/edit} do |kind, id|
      require_authentication!
      room = repo.user_room(current_user.id, id.to_i)
      return redirect_with_alert("/", "Room not found or inaccessible") unless room && !room.direct?
      render_room_settings(kind.chomp("s"), room)
    end

    get %r{/rooms/(opens|closeds)/(\d+)} do |_kind, id|
      require_authentication!
      room = repo.user_room(current_user.id, id.to_i)
      return redirect_with_alert("/", "Room not found or inaccessible") unless room && !room.direct?
      remember_last_room_visited(room)
      redirect url_for("/rooms/#{room.id}")
    end

    post %r{/rooms/(opens|closeds)} do |kind|
      verify_same_origin!
      require_authentication!
      halt 403, "" unless can_create_rooms?
      room = Rooms.create(self, kind == "opens" ? "Rooms::Open" : "Rooms::Closed", (params["room"] || {})["name"].to_s, Array(params["user_ids"]))
      redirect url_for("/rooms/#{room.id}")
    end

    patch %r{/rooms/(opens|closeds)/(\d+)} do |kind, id|
      verify_same_origin!
      require_authentication!
      room = repo.user_room(current_user.id, id.to_i)
      return redirect_with_alert("/", "Room not found or inaccessible") unless room && !room.direct?
      halt 403, "" unless current_user.can_administer?(room)
      room = Rooms.update(self, room, kind == "opens" ? "Rooms::Open" : "Rooms::Closed", (params["room"] || {})["name"], Array(params["user_ids"]))
      redirect url_for("/rooms/#{room.id}")
    end

    get "/rooms/directs/new" do
      require_authentication!
      view = build_view
      render_layout(view, main: view.tpl_rooms_direct_new)
    end

    post "/rooms/directs" do
      verify_same_origin!
      require_authentication!
      room = Rooms.find_or_create_direct(self, (Array(params["user_ids"]).map(&:to_i) + [ current_user.id ]).uniq)
      redirect url_for("/rooms/#{room.id}")
    end

    get %r{/rooms/directs/(\d+)/edit} do |id|
      require_authentication!
      room = repo.user_room(current_user.id, id.to_i)
      return redirect_with_alert("/", "Room not found or inaccessible") unless room&.direct?
      users = repo.room_users(room.id)
      members = users.size > 1 ? users.reject { it.id == current_user.id } : users
      view = build_view(room: room, members: members, last_room_visited: last_room_visited)
      render_layout(view, page_title: "Edit settings for #{view.room_display_name(room)}", nav: view.tpl_rooms_settings_nav, main: view.tpl_rooms_direct_edit)
    end

    get %r{/rooms/directs/(\d+)} do |id|
      require_authentication!
      room = repo.user_room(current_user.id, id.to_i)
      return redirect_with_alert("/", "Room not found or inaccessible") unless room&.direct?
      redirect url_for("/rooms/#{room.id}")
    end

    delete %r{/rooms(?:/directs)?/(\d+)} do |id|
      verify_same_origin!
      require_authentication!
      room = repo.user_room(current_user.id, id.to_i)
      return redirect_with_alert("/", "Room not found or inaccessible") unless room && (room.direct? == request.path_info.include?("/directs/"))
      halt 403, "" unless room.direct? || current_user.can_administer?(room)
      Rooms.destroy(self, room)
      redirect url_for("/")
    end

    # ---- Account

    get "/account/edit" do
      require_authentication!
      statuses = current_user.can_administer? ? "0, 2" : "0"
      users = db.rows("SELECT #{User.columns} FROM users WHERE status IN (#{statuses}) AND role != 2 ORDER BY LOWER(name)").map { User.new(*it) }
      administrators, members = users.partition(&:administrator?)
      view = build_view(administrators: administrators, members: members, next_page: users.size > 500 ? 2 : nil,
        last_room_visited: last_room_visited)
      footer = %(<div class="txt-align-center center margin-block-double txt-subtle">Campfire&trade; version <span class="version-badge">#{HTML.h(runtime.app_version)}</span></div>)
      render_layout(view, page_title: "Account settings", nav: view.tpl_accounts_edit_nav, main: view.tpl_accounts_edit, footer: footer)
    end

    [ :patch, :put ].each do |verb|
      send(verb, %r{/account(?:\.\d+)?}) { update_account }
    end

    helpers do
      def update_account
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      Accounts.update(self, params["account"] || {})
      redirect_with_notice("/account/edit", "✓")
      end
    end

    get %r{/account/users(?:\.turbo_stream)?} do
      require_authentication!
      page = [ params["page"].to_i, 1 ].max
      users = db.rows("SELECT #{User.columns} FROM users WHERE status = 0 AND role != 2 ORDER BY LOWER(name) LIMIT 500 OFFSET ?", (page - 1) * 500).map { User.new(*it) }
      more = db.value("SELECT COUNT(*) FROM users WHERE status = 0 AND role != 2") > page * 500
      view = build_view
      html = %(<turbo-stream action="replace" target="next_page_container"><template>#{users.map { view.render_account_user(it) }.join}</template></turbo-stream>)
      html << %(<turbo-stream action="append" target="account_users"><template><turbo-frame loading="lazy" src="/account/users.turbo_stream?page=#{page + 1}" class="flex center" id="next_page_container">\n  <div class="spinner center"></div>\n</turbo-frame></template></turbo-stream>) if more
      html_headers("text/vnd.turbo-stream.html")
      html
    end

    patch %r{/account/users/(\d+)} do |id|
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      user = repo.user(id.to_i)
      halt 404 unless user&.active?
      role = %w[ member administrator ].include?((params["user"] || {})["role"]) ? params["user"]["role"] : "member"
      db.transaction { |w| w.run("UPDATE users SET role = ?, updated_at = ? WHERE id = ?", role == "administrator" ? 1 : 0, TimeFormat.now_text, user.id) }
      redirect url_for("/account/edit")
    end

    delete %r{/account/users/(\d+)} do |id|
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      user = repo.user(id.to_i)
      halt 404 unless user&.active?
      Accounts.deactivate(self, user)
      redirect url_for("/account/edit")
    end

    post "/account/join_code" do
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      code = SecureRandom.alphanumeric(12).scan(/.{4}/).join("-")
      db.transaction { |w| w.run("UPDATE accounts SET join_code = ?, updated_at = ?", code, TimeFormat.now_text) }
      redirect url_for("/account/edit")
    end

    get "/account/custom_styles/edit" do
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      view = build_view
      render_layout(view, page_title: "Custom styles", nav: view.tpl_accounts_custom_styles_nav, main: view.tpl_accounts_custom_styles)
    end

    patch "/account/custom_styles" do
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      db.transaction { |w| w.run("UPDATE accounts SET custom_styles = ?, updated_at = ?", (params["account"] || {})["custom_styles"], TimeFormat.now_text) }
      redirect_with_notice("/account/custom_styles/edit", "✓")
    end

    delete "/account/logo" do
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      db.transaction do |w|
        w.run("DELETE FROM active_storage_attachments WHERE record_type = 'Account' AND name = 'logo'")
        w.run("UPDATE accounts SET updated_at = ?", TimeFormat.now_text)
      end
      redirect url_for("/account/edit")
    end

    # ---- Bots

    get "/account/bots" do
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      bots = db.rows("SELECT #{User.columns} FROM users WHERE status = 0 AND role = 2 ORDER BY LOWER(name)").map { User.new(*it) }
      bots = bots.map do |bot|
        rooms = db.rows(<<~SQL, bot.id).map { Room.new(*it) }
          SELECT #{Room.columns} FROM rooms INNER JOIN memberships ON rooms.id = memberships.room_id
          WHERE memberships.user_id = ? AND rooms.type != 'Rooms::Direct' ORDER BY LOWER(name)
        SQL
        [ bot, rooms ]
      end
      view = build_view(bots: bots, back_path: "/account/edit")
      render_layout(view, page_title: "Chat bots", nav: view.tpl_bots_back_nav, main: view.tpl_bots_index)
    end

    get "/account/bots/new" do
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      view = build_view(bot: nil, bot_avatar_src: Assets.path("default-bot-avatar.svg"), webhook_url: nil, back_path: "/account/bots")
      render_layout(view, page_title: "New chat bot", nav: view.tpl_bots_back_nav, main: view.tpl_bots_form)
    end

    get %r{/account/bots/(\d+)/edit} do |id|
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      bot = active_bot!(id)
      avatar = repo.attachment_blob("User", bot.id, "avatar")
      view = build_view(bot: bot, bot_avatar_src: avatar ? url_for(Storage.blob_path(runtime, avatar)) : Assets.path("default-bot-avatar.svg"),
        webhook_url: db.value("SELECT url FROM webhooks WHERE user_id = ? LIMIT 1", bot.id), back_path: "/account/bots")
      render_layout(view, page_title: "Edit bot", nav: view.tpl_bots_back_nav, main: view.tpl_bots_form)
    end

    post "/account/bots" do
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      BotAccounts.create(self, params["user"] || {})
      redirect url_for("/account/bots")
    end

    patch %r{/account/bots/(\d+)} do |id|
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      BotAccounts.update(self, active_bot!(id), params["user"] || {})
      redirect url_for("/account/bots")
    end

    put %r{/account/bots/(\d+)/key} do |id|
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      bot = active_bot!(id)
      db.transaction { |w| w.run("UPDATE users SET bot_token = ?, updated_at = ? WHERE id = ?", SecureRandom.alphanumeric(12), TimeFormat.now_text, bot.id) }
      redirect url_for("/account/bots")
    end

    delete %r{/account/bots/(\d+)} do |id|
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      Accounts.deactivate(self, active_bot!(id))
      redirect url_for("/account/bots")
    end

    # ---- Autocomplete, PWA, push subscriptions

    get %r{/autocompletable/users(\.json)?} do |json|
      require_authentication!
      query = params["filter"].to_s.empty? ? params["query"].to_s : params["filter"].to_s
      users = Autocomplete.users(self, params["room_id"], query)
      if json || request.accept.first&.to_s == "application/json"
        headers "Content-Type" => "application/json; charset=utf-8"
        RailsJSON.generate(users.map { { name: HTML.h(it.name), value: it.id, avatar_url: url_for(build_view.avatar_path(it)), sgid: secrets.attachable_sgid("User", it.id) } })
      else
        view = build_view
        html_headers
        users.map { Autocomplete.prompt_item(view, it) }.join
      end
    end

    get %r{/webmanifest(\.json)?} do
      account = runtime.account
      view = build_view
      headers "Content-Type" => "application/json; charset=utf-8", "Cache-Control" => "max-age=0, private, must-revalidate"
      Pwa.manifest(view, account, base_url)
    end

    get %r{/service-worker(\.js)?} do
      headers "Content-Type" => "text/javascript; charset=utf-8", "Cache-Control" => "max-age=0, private, must-revalidate"
      File.read(File.join(ROOT, "public/service-worker.js"))
    end

    get "/users/me/push_subscriptions" do
      require_authentication!
      subscriptions = db.rows("SELECT id, endpoint, user_agent FROM push_subscriptions WHERE user_id = ?", current_user.id)
      view = build_view(subscriptions: subscriptions, last_room_visited: last_room_visited)
      render_layout(view, page_title: "Push notification subscriptions", nav: view.tpl_rooms_settings_nav, main: view.tpl_push_index)
    end

    post "/users/me/push_subscriptions" do
      verify_same_origin!
      require_authentication!
      attributes = params["push_subscription"] || {}
      halt 400, "" if attributes.empty?
      status PushSubscriptions.create(self, attributes) ? 200 : 422
      ""
    end

    delete %r{/users/me/push_subscriptions/(\d+)} do |id|
      verify_same_origin!
      require_authentication!
      db.transaction { |w| w.run("DELETE FROM push_subscriptions WHERE id = ? AND user_id = ?", id.to_i, current_user.id) }
      redirect url_for("/users/me/push_subscriptions")
    end

    post %r{/users/me/push_subscriptions/(\d+)/test_notifications} do |id|
      verify_same_origin!
      require_authentication!
      row = db.row("SELECT endpoint, p256dh_key, auth_key FROM push_subscriptions WHERE id = ? AND user_id = ?", id.to_i, current_user.id) or halt 404
      payload = { title: "Campfire Test", body: SecureRandom.uuid, path: url_for("/users/me/push_subscriptions") }
      badge = db.value("SELECT COUNT(*) FROM memberships WHERE user_id = ? AND unread_at IS NOT NULL", current_user.id)
      Push.deliver(runtime, id.to_i, *row, payload, badge) if Push.permitted?(row[0])
      redirect url_for("/users/me/push_subscriptions")
    end

    post "/unfurl_link" do
      verify_same_origin!
      require_authentication!
      halt 400, "" if params["url"].to_s.empty?
      if (metadata = Unfurl.metadata(params["url"].to_s))
        headers "Content-Type" => "application/json; charset=utf-8"
        RailsJSON.generate(metadata)
      else
        status 204
        ""
      end
    end

    # ---- Bot API: /rooms/:room_id/:bot_key/messages

    get %r{/rooms/(\d+)/(\d+-[A-Za-z0-9]+)/messages(?:\.json)?} do |room_id, bot_key|
      bot, room = bot_room!(bot_key, room_id)
      messages =
        if !params["before"].to_s.empty? then repo.page_before(room.id, (repo.room_message(room.id, params["before"].to_i) or halt 404).created_at)
        elsif !params["after"].to_s.empty? then repo.page_after(room.id, (repo.room_message(room.id, params["after"].to_i) or halt 404).created_at)
        else repo.last_page(room.id)
        end
      headers "X-Total-Count" => repo.room_message_count(room.id).to_s
      if (link = BotApi.next_page_link(self, room, bot_key, messages))
        headers "Link" => link
      end
      headers "Content-Type" => "application/json; charset=utf-8"
      RailsJSON.generate(messages.map { BotApi.message_json(self, it) })
    end

    post %r{/rooms/(\d+)/(\d+-[A-Za-z0-9]+)/messages(?:\.json)?} do |room_id, bot_key|
      bot, room = bot_room!(bot_key, room_id)
      @current_user = bot
      attachment = params["attachment"]
      request.body.rewind
      raw = request.body.read.to_s.force_encoding("UTF-8")
      halt 422, "" if attachment.to_s.empty? && raw.empty?
      message_params = attachment.is_a?(Hash) ? { "attachment" => attachment } : { "body" => raw }
      message = Messages.create(self, room: room, creator: bot, params: message_params)
      Messages.after_create(self, room, message, message_views([ message ]).first)
      status 201
      headers "Location" => url_for("/messages/#{message.id}")
      ""
    end

    route_verbs = [ :put, :patch ]
    route_verbs.each do |verb|
      send(verb, %r{/rooms/(\d+)/(\d+-[A-Za-z0-9]+)/messages/(\d+)(?:\.json)?}) do |room_id, bot_key, id|
        bot, room = bot_room!(bot_key, room_id)
        @current_user = bot
        message = repo.room_message(room.id, id.to_i) or halt 404
        halt 403, "" unless bot.can_administer?(message)
        message = Messages.update(self, room, message, (params["message"] || {})["body"])
        headers "Content-Type" => "application/json; charset=utf-8"
        RailsJSON.generate(BotApi.message_json(self, message))
      end
    end

    delete %r{/rooms/(\d+)/(\d+-[A-Za-z0-9]+)/messages/(\d+)(?:\.json)?} do |room_id, bot_key, id|
      bot, room = bot_room!(bot_key, room_id)
      message = repo.room_message(room.id, id.to_i) or halt 404
      halt 403, "" unless bot.can_administer?(message)
      MessageRemoval.destroy(runtime, message)
      Broadcasts.turbo_stream("#{RailsCompat.gid_param(room.type, room.id)}:messages", %(<turbo-stream action="remove" target="message_#{message.client_message_id}"></turbo-stream>))
      status 204
      ""
    end

    # ---- Users, profiles, bans

    get %r{/users/(\d+)} do |id|
      require_authentication!
      user = repo.user(id.to_i) or halt 404
      view = build_view(user: user)
      render_layout(view, page_title: user.name, nav: view.tpl_users_show_nav, main: view.tpl_users_show)
    end

    get "/users/me/profile" do
      require_authentication!
      memberships = repo.sidebar_memberships(current_user.id, visible_only: false)
      directs, shared = memberships.partition { |_, room| room.direct? }
      view = build_view(user: current_user, direct_memberships: directs, shared_memberships: shared,
        avatar_attached: !repo.attachment_blob("User", current_user.id, "avatar").nil?)
      render_layout(view, page_title: current_user.name, nav: view.tpl_profiles_show_nav, main: view.tpl_profiles_show)
    end

    patch "/users/me/profile" do
      verify_same_origin!
      require_authentication!
      attributes = params["user"] || {}
      Profiles.update(self, current_user, attributes)
      redirect_with_notice("/users/me/profile", attributes["avatar"] ? "It may take up to 30 minutes to change everywhere." : "✓")
    end

    delete %r{/users/(me|\d+)/avatar} do
      verify_same_origin!
      require_authentication!
      Profiles.remove_avatar(self, current_user)
      redirect url_for("/users/me/profile")
    end

    post %r{/users/(\d+)/ban} do |id|
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      user = repo.user(id.to_i) or halt 404
      Bans.ban(self, user)
      redirect url_for("/users/#{user.id}")
    end

    delete %r{/users/(\d+)/ban} do |id|
      verify_same_origin!
      require_authentication!
      halt 403, "" unless current_user.can_administer?
      user = repo.user(id.to_i) or halt 404
      Bans.unban(self, user)
      redirect url_for("/users/#{user.id}")
    end

    # ---- Involvement

    get %r{/rooms/(\d+)/involvement} do |room_id|
      require_authentication!
      membership = repo.membership(current_user.id, room_id.to_i) or halt 404
      room = repo.room(membership.room_id)
      view = build_view
      frame = %(<turbo-frame data-controller="turbo-frame" data-action="notifications:ready@window-&gt;turbo-frame#load" data-turbo-frame-url-param="/rooms/#{room.id}/involvement" id="involvement_#{room.param_key}_#{room.id}">\n  #{view.involvement_button(room, membership.involvement)}\n</turbo-frame>)
      render_layout(view, main: frame)
    end

    put %r{/rooms/(\d+)/involvement} do |room_id|
      verify_same_origin!
      require_authentication!
      membership = repo.membership(current_user.id, room_id.to_i) or halt 404
      Involvements.update(self, membership, params["involvement"].to_s)
      redirect url_for("/rooms/#{membership.room_id}/involvement")
    end

    # ---- Message show, edit, update, destroy

    get %r{/rooms/(\d+)/messages/(\d+)} do |room_id, id|
      require_authentication!
      room = room_scoped!(room_id)
      message = repo.room_message(room.id, id.to_i) or halt 404
      view = build_view
      render_layout(view, main: view.render_message_cached(message_views([ message ]).first))
    end

    get %r{/rooms/(\d+)/messages/(\d+)/edit} do |room_id, id|
      require_authentication!
      room = room_scoped!(room_id)
      message = repo.room_message(room.id, id.to_i) or halt 404
      halt 403, "" unless current_user.can_administer?(message)
      message_view = Messages.views(self, [ message ], cached: false).first
      body = repo.bodies([ message.id ])[message.id]
      view = build_view(view: message_view, message: message, room: room, editor_value: Messages.editor_value(self, body))
      render_layout(view, main: view.tpl_messages_edit)
    end

    patch %r{/rooms/(\d+)/messages/(\d+)} do |room_id, id|
      verify_same_origin!
      require_authentication!
      room = room_scoped!(room_id)
      message = repo.room_message(room.id, id.to_i) or halt 404
      halt 403, "" unless current_user.can_administer?(message)
      message = Messages.update(self, room, message, (params["message"] || {})["body"])
      redirect url_for("/rooms/#{room.id}/messages/#{message.id}")
    end

    delete %r{/rooms/(\d+)/messages/(\d+)} do |room_id, id|
      verify_same_origin!
      require_authentication!
      room = room_scoped!(room_id)
      message = repo.room_message(room.id, id.to_i) or halt 404
      halt 403, "" unless current_user.can_administer?(message)
      MessageRemoval.destroy(runtime, message)
      remove = %(<turbo-stream action="remove" target="message_#{message.client_message_id}"></turbo-stream>)
      Broadcasts.turbo_stream("#{RailsCompat.gid_param(room.type, room.id)}:messages", remove)
      html_headers("text/vnd.turbo-stream.html")
      remove
    end

    get %r{/rooms/(\d+)/refresh} do |room_id|
      require_authentication!
      # respond_to turbo_stream only
      unless request.env["HTTP_ACCEPT"].to_s.include?("text/vnd.turbo-stream.html")
        without_security_headers
        without_version_headers
        halt 406, { "Content-Type" => "text/html; charset=utf-8" }, ""
      end
      room = room_scoped!(room_id)
      since = TimeFormat.dump(Time.at(0, params["since"].to_i, :millisecond))
      created = repo.messages_created_since(room.id, since)
      updated = repo.messages_updated_since(room.id, since, created.map(&:id))
      view = build_view
      html = +""
      html << %(<turbo-stream action="append" target="messages_#{room.param_key}_#{room.id}"><template>#{message_views(created).map { view.render_message_cached(it) }.join}</template></turbo-stream>) if created.any?
      message_views(updated).each do |message_view|
        html << %(<turbo-stream action="replace" target="message_#{message_view.message.client_message_id}"><template>#{view.render_message_cached(message_view)}</template></turbo-stream>)
      end
      html_headers("text/vnd.turbo-stream.html")
      html
    end

    # ---- Boosts

    get %r{/messages/(\d+)/boosts} do |message_id|
      require_authentication!
      message = reachable_message!(message_id)
      view = build_view
      message_view = Messages.views(self, [ message ], cached: false).first
      render_layout(view, main: view.with(message: message, view: message_view).render_boosts(message_view))
    end

    get %r{/messages/(\d+)/boosts/new} do |message_id|
      require_authentication!
      message = reachable_message!(message_id)
      view = build_view(message: message)
      render_layout(view, main: view.tpl_boosts_new)
    end

    post %r{/messages/(\d+)/boosts} do |message_id|
      verify_same_origin!
      require_authentication!
      message = reachable_message!(message_id)
      Boosts.create(self, message, (params["boost"] || {})["content"].to_s)
      redirect url_for("/messages/#{message.id}/boosts")
    end

    delete %r{/messages/(\d+)/boosts/(\d+)} do |message_id, id|
      verify_same_origin!
      require_authentication!
      message = reachable_message!(message_id)
      Boosts.destroy(self, message, id.to_i) or halt 404
      status 204
      ""
    end

    # ---- Sidebar

    get %r{/users/(me|\d+)/sidebar} do
      require_authentication!
      html_headers
      render_sidebar
    end

    # ---- Searches

    get "/searches" do
      require_authentication!
      raw = params["q"]
      query = raw&.gsub(/[^[:word:]]/, " ")
      messages = query.to_s.strip.empty? ? [] : repo.search(current_user.id, query)
      render_search(query.to_s.strip.empty? ? nil : query, raw, messages)
    end

    post "/searches" do
      verify_same_origin!
      require_authentication!
      query = params["q"]&.gsub(/[^[:word:]]/, " ")
      Searches.record(self, current_user, query)
      redirect url_for("/searches?q=#{URI.encode_www_form_component(query.to_s)}")
    end

    delete "/searches/clear" do
      verify_same_origin!
      require_authentication!
      db.transaction { |w| w.run("DELETE FROM searches WHERE user_id = ?", current_user.id) }
      redirect url_for("/searches")
    end

    # ---- Avatars and account logo

    get "/users/:token/avatar" do
      require_authentication!
      Avatars.show(self, params["token"])
    end

    get "/account/logo" do
      Avatars.account_logo(self)
    end

    # ---- QR codes and Active Storage

    get "/qr_code/:id" do
      QrCodes.show(self, params["id"])
    end

    get "/rails/active_storage/blobs/redirect/:signed_id/*" do
      blob = signed_blob!(params["signed_id"])
      redirect_to_disk(blob, params["disposition"])
    end

    get "/rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*" do
      blob = signed_blob!(params["signed_blob_id"])
      transformations = Storage.verify(runtime, params["variation_key"], "variation") or active_storage_not_found
      # ActiveStorage::Preview: a video's representation is a variant of its stored preview image.
      if blob.video?
        row = db.row(<<~SQL, blob.id) or halt 404
          SELECT #{Blob.columns} FROM active_storage_attachments JOIN active_storage_blobs ON active_storage_blobs.id = active_storage_attachments.blob_id
          WHERE active_storage_attachments.record_type = 'ActiveStorage::Blob' AND active_storage_attachments.record_id = ? AND active_storage_attachments.name = 'preview_image' LIMIT 1
        SQL
        blob = Blob.new(*row)
      end
      variant = Uploads.variant_blob(Context.new(runtime), blob, transformations)
      redirect_to_disk(variant, params["disposition"])
    end

    get "/rails/active_storage/disk/:encoded_key/*" do
      without_version_headers
      key = Storage.verify(runtime, params["encoded_key"], "blob_key") or active_storage_not_found
      path = Storage.path_for(key["key"].to_s)
      active_storage_not_found unless File.file?(path)
      headers "Cache-Control" => "max-age=3600, public", "Content-Disposition" => key["disposition"].to_s
      send_file path, type: key["content_type"] || "application/octet-stream", disposition: nil
    end

    # ---- Helpers

    helpers do
      # Rails' redirect_to: always 302 (Sinatra answers non-GET HTTP/1.1 requests with 303).
      def redirect(uri, *args)
        status 302
        response["Location"] = uri
        headers "Content-Type" => "text/html; charset=utf-8", "Cache-Control" => "no-cache"
        halt(*args)
      end

      def current_user = @current_user
      def base_url = (@base_url ||= "#{request.scheme}://#{request.host_with_port}")
      def url_for(path) = "#{base_url}#{path}"

      def build_view(**locals)
        view = View.new(app: runtime, current_user: current_user, base_url: base_url, user_agent: request.user_agent, flash: flash_now)
          .with(referrer: request.referer, request_url: request.url, **locals)
        if @collect_fragments && !@fragment_view
          @fragment_view = view
          view.collecting_fragments { }
        end
        view
      end

      def html_headers(type = "text/html")
        headers "Cache-Control" => "max-age=0, private, must-revalidate", "Content-Type" => "#{type}; charset=utf-8"
        headers "Vary" => "Accept" if vary_by_accept?
      end

      # ActionDispatch::Request#should_apply_vary_header?: only when the format came from a
      # non-browser Accept header.
      def vary_by_accept?
        accept = request.env["HTTP_ACCEPT"].to_s
        params["format"].to_s.empty? && !accept.empty? && !accept.match?(/,\s*\*\/\*|\*\/\*\s*,/)
      end

      def without_version_headers
        response.headers.delete("X-Version")
        response.headers.delete("X-Rev")
      end

      # Avatars and the account logo go out without ActionDispatch's default headers, as Rails sends them.
      def without_security_headers
        SECURITY_HEADERS.each_key { response.headers.delete(it) }
      end

      # send_file as ActionController::DataStreaming writes it.
      def send_inline_file(path, type)
        without_security_headers
        headers "Content-Type" => type, "Content-Transfer-Encoding" => "binary",
          "Content-Disposition" => Storage.content_disposition("inline", File.basename(path))
        File.binread(path)
      end

      # The ETag of a page built from cached message fragments: everything it's rendered from.
      def page_etag(*parts)
        headers "ETag" => %(W/"#{Digest::MD5.hexdigest([ base_url, request.user_agent, current_user&.id, current_user&.updated_at, current_user&.role, *parts ].join("|"))}")
      end

      def render_layout(view, main:, page_title: nil, body_class: nil, head: nil, nav: nil, footer: nil, sidebar: nil)
        html_headers
        # Turbo::Frames::FrameRequest: frame requests get turbo-rails' bare frame layout.
        if request.env["HTTP_TURBO_FRAME"].to_s != ""
          return "<html>\n  <head>\n    \n    #{head}\n  </head>\n  <body>\n    #{main}\n  </body>\n</html>\n"
        end

        view.with(page_title: page_title, body_class: body_class, content_head: head, content_nav: nav, content_main: main,
          content_footer: footer, content_sidebar: sidebar)
        headers "Link" => Assets.link_header
        view.tpl_layouts_application
      end

      def render_page(template, page_title: nil, head: nil, body_class: nil, **locals)
        view = build_view(**locals)
        render_layout(view, main: view.public_send(:"tpl_#{template}"), page_title: page_title, head: head, body_class: body_class)
      end

      def flash_now
        @flash ||= read_flash
      end

      def render_sign_in_rejection(code)
        flash_now["alert"] = "Too many requests or unauthorized."
        status code
        render_page(:sessions_new, page_title: "Sign in", head: %(<meta name="turbo-visit-control" content="reload">), email_address: params["email_address"])
      end

      def render_incompatible_browser
        view = build_view
        render_layout(view, main: view.tpl_sessions_incompatible_browser,
          page_title: Platform.new(request.user_agent).apple_messages? ? "Campfire" : "Unsupported browser")
      end

      def signed_blob!(signed_id)
        id = Storage.find_signed_blob_id(runtime, signed_id) or active_storage_not_found
        row = db.row("SELECT #{Blob.columns} FROM active_storage_blobs WHERE id = ?", id) or active_storage_not_found
        Blob.new(*row)
      end

      # Active Storage's controllers aren't ApplicationControllers: a missing blob is the public 404
      # page, without version headers.
      def active_storage_not_found
        without_version_headers
        halt 404, { "Content-Type" => "text/html", "Cache-Control" => "no-cache" }, File.read(File.join(ROOT, "public/404.html"))
      end

      # ActiveStorage::Blobs::RedirectController and Representations::RedirectController
      def redirect_to_disk(blob, disposition)
        without_version_headers
        disposition = disposition == "attachment" ? "attachment" : "inline"
        headers "Cache-Control" => "max-age=300, private"
        redirect url_for(Storage.disk_path(runtime, key: blob.key, filename: blob.filename, content_type: blob.content_type,
          disposition: Storage.content_disposition(disposition, blob.filename)))
      end

      # ---- Authentication

      def restore_authentication
        return @current_user if defined?(@current_user) && @current_user
        raw = request.cookies["session_token"] or return nil
        token = secrets.verify_cookie("session_token", raw) or return nil
        session = repo.session_by_token(token) or return nil
        user = repo.user(session.user_id) or return nil
        resume_session(session)
        @session = session
        @current_user = user
      end

      def require_authentication!
        return if restore_authentication

        if request.get? || request.head?
          write_session("return_to_after_authenticating" => request.url)
        end
        without_version_headers # the before_action that sets them comes after require_authentication
        halt redirect(url_for("/session/new"))
      end

      def resume_session(session)
        if TimeFormat.parse(session.last_active_at) < Time.now - SESSION_REFRESH
          now = TimeFormat.now_text
          db.transaction do |w|
            w.run("UPDATE sessions SET user_agent = ?, ip_address = ?, last_active_at = ?, updated_at = ? WHERE id = ?",
              request.user_agent, request.ip, now, now, session.id)
          end
          set_session_cookie(session.token)
        end
      end

      def start_new_session_for(user)
        token = Tokens.base58(24)
        now = TimeFormat.now_text
        db.transaction do |w|
          w.run("INSERT INTO sessions (created_at, ip_address, last_active_at, token, updated_at, user_agent, user_id) VALUES (?, ?, ?, ?, ?, ?, ?)",
            now, request.ip, now, token, now, request.user_agent, user.id)
        end
        set_session_cookie(token)
        @current_user = user
      end

      def set_session_cookie(token)
        expires = permanent_expiry
        response.set_cookie("session_token", value: secrets.sign_cookie("session_token", token, expires), path: "/",
          expires: expires, httponly: true, same_site: :lax)
      end

      def permanent_expiry
        now = Time.now.utc
        Time.utc(now.year + PERMANENT_YEARS, now.month, now.day, now.hour, now.min, now.sec, now.usec)
      end

      def redirect_after_authentication
        session = read_session
        target = session.delete("return_to_after_authenticating")
        write_session(session) if target
        redirect target || url_for("/")
      end

      # ---- The Rails session cookie, used here only for flash and the post-login redirect.

      def read_session
        raw = request.cookies["_campfire_session"]
        (raw && secrets.decrypt_cookie("_campfire_session", raw)) || {}
      end

      def write_session(hash)
        if hash.empty?
          response.delete_cookie("_campfire_session", path: "/")
        else
          expires = Time.now.utc + PERMANENT_YEARS * 365.25 * 86_400
          response.set_cookie("_campfire_session", value: secrets.encrypt_cookie("_campfire_session", hash, expires), path: "/",
            expires: expires, httponly: true, same_site: :lax)
        end
      end

      def read_flash
        return {} unless request.cookies["_campfire_session"]
        session = read_session
        flash = session.delete("flash")
        return {} unless flash
        write_session(session)
        (flash["flashes"] || {}).reject { |key, _| Array(flash["discard"]).include?(key) }
      end

      def redirect_with_alert(path, alert) = redirect_with_flash(path, "alert", alert)
      def redirect_with_notice(path, notice) = redirect_with_flash(path, "notice", notice)

      def redirect_with_flash(path, key, message)
        session = read_session
        session["flash"] = { "discard" => [], "flashes" => { key => message } }
        write_session(session)
        redirect url_for(path)
      end

      # Sec-Fetch-Site replaces CSRF tokens, as in the Rust port: cross-site writes are rejected,
      # and so is a mismatched Origin.
      def verify_same_origin!
        site = request.env["HTTP_SEC_FETCH_SITE"]
        origin = request.env["HTTP_ORIGIN"]
        forbidden = site == "cross-site" || (site.nil? && request.scheme == "https") ||
          (origin && origin != "null" && origin != base_url)
        halt 422, "" if forbidden
      end

      # ---- Rooms

      # Authentication's restore_authentication || bot_authentication, then the user's room
      def bot_room!(bot_key, room_id)
        bot = restore_authentication
        unless bot
          id, token = bot_key.strip.split("-", 2)
          row = db.row("SELECT #{User.columns} FROM users WHERE id = ? AND bot_token = ? AND status = 0 AND role = 2 LIMIT 1", id.to_i, token.to_s)
          halt 302, { "Location" => url_for("/session/new") }, "" unless row
          bot = User.new(*row)
        end
        room = repo.user_room(bot.id, room_id.to_i) or halt 404, ""
        [ bot, room ]
      end

      def active_bot!(id)
        row = db.row("SELECT #{User.columns} FROM users WHERE id = ? AND status = 0 AND role = 2", id.to_i) or halt 404
        User.new(*row)
      end

      def can_create_rooms?
        current_user.administrator? || !runtime.account.restrict_room_creation_to_administrators?
      end

      def render_room_settings(form_type, room)
        users = repo.active_users_ordered
        editing = !room.nil?
        administer = editing ? current_user.can_administer?(room) : true
        if form_type == "closed"
          member_ids = editing ? repo.room_user_ids(room.id) : []
          selected, unselected = users.partition { member_ids.include?(it.id) }
        else
          selected, unselected = [], users
        end
        type_change_path = editing ? "/rooms/#{form_type == "open" ? "closeds" : "opens"}/#{room.id}/edit" : "/rooms/#{form_type == "open" ? "closeds" : "opens"}/new"
        view = build_view(room: room, editing: editing, form_type: form_type, can_administer: administer,
          room_name: editing ? room.name : "New room", type_change_path: type_change_path, user_count: users.size,
          selected_users: selected, unselected_users: unselected, last_room_visited: last_room_visited)
        render_layout(view, page_title: editing ? "Edit settings for #{room.name}" : "New chat room",
          nav: view.tpl_rooms_settings_nav, main: view.tpl_rooms_settings)
      end

      def reachable_message!(id)
        row = db.row(<<~SQL, current_user.id, id.to_i) or halt 404
          SELECT #{Message.columns} FROM messages INNER JOIN rooms ON messages.room_id = rooms.id
          INNER JOIN memberships ON rooms.id = memberships.room_id WHERE memberships.user_id = ? AND messages.id = ? LIMIT 1
        SQL
        Message.new(*row)
      end

      def room_scoped!(room_id)
        membership = repo.membership(current_user.id, room_id.to_i) or halt 404
        repo.room(membership.room_id)
      end

      def remember_last_room_visited(room)
        if request.cookies["last_room"] != room.id.to_s
          response.set_cookie("last_room", value: room.id.to_s, path: "/", expires: permanent_expiry, same_site: :lax)
        end
      end

      def last_room_visited
        (id = request.cookies["last_room"]) && repo.user_room(current_user.id, id.to_i) || repo.user_original_room(current_user.id)
      end

      def find_room_messages(room, message_id)
        if message_id && (anchor = repo.room_message(room.id, message_id.to_i))
          repo.page_before(room.id, anchor.created_at) + [ anchor ] + repo.page_after(room.id, anchor.created_at)
        else
          repo.last_page(room.id)
        end
      end

      def render_room(room, messages)
        fragment_page { render_room_page(room, messages) }
      end

      # A page whose message fragments go out as a FragmentBody (cached gzip blocks).
      def fragment_page
        @collect_fragments = true
        html = yield
        view = @fragment_view
        body = view&.fragments ? FragmentBody.from(html, view.fragments) : [ html ]
        headers "Content-Length" => body.is_a?(FragmentBody) ? body.bytesize.to_s : html.bytesize.to_s
        body
      ensure
        @collect_fragments = false
      end

      def render_room_page(room, messages)
        views = message_views(messages)
        invitation = room.id == repo.original_room_id && repo.room_message_count(room.id) <= Repo::PAGE_SIZE
        account = runtime.account
        page_etag("room", room, account.updated_at, account.name, invitation, messages.map { "#{it.id}-#{it.updated_at}" },
          (repo.direct_room_member_names(room.id, current_user.id) if room.direct?), flash_now)
        view = build_view(room: room, messages: views, invitation: invitation)
        render_layout(view,
          page_title: view.room_display_name(room), body_class: "sidebar",
          head: view.tpl_rooms_head, nav: view.tpl_rooms_nav, main: view.tpl_rooms_show, footer: view.tpl_rooms_composer,
          sidebar: sidebar_frame_tag)
      end

      def render_welcome
        view = build_view
        main = <<~HTML
          <div id="message-area" class="message-area">
            <div class="message-area--empty min-width center">
              <figure class="center pad">
                #{view.image_tag("messages-empty.svg", aria: { hidden: "true" }, class: "colorize--black translucent")}
                <span class="for-screen-reader">#{HTML.h(current_user.name)}</span>
              </figure>
            </div>
          </div>
        HTML
        render_layout(view, main: main, page_title: "No rooms yet", body_class: "sidebar", sidebar: sidebar_frame_tag)
      end

      def sidebar_frame_tag
        %(<turbo-frame data-turbo-permanent="true" data-controller="rooms-list read-rooms turbo-frame" data-rooms-list-unread-class="unread" data-action="presence:present@window->rooms-list#read read-rooms:read->rooms-list#read turbo:frame-load->rooms-list#loaded refresh-room:visible@window->turbo-frame#reload" id="user_sidebar" src="/users/me/sidebar" target="_top"></turbo-frame>)
      end

      def render_room_not_found
        html_headers("text/vnd.turbo-stream.html")
        %(<turbo-stream action="update" target="message-area"><template><div class="message-area--empty min-width center txt-medium">This room has been deleted.</div></template></turbo-stream>)
      end

      def messages_html(messages)
        fragment_page do
          view = build_view
          message_views(messages).map { view.render_message_cached(it) }.join
        end
      end

      # ActionController::ConditionalGet#fresh_when(@messages): the collection's cache key.
      def etag_for_messages(messages)
        page_etag("messages", messages.map { "#{it.id}-#{it.updated_at}" })
      end

      # The data each message partial needs, loaded only for messages not already in the fragment
      # cache (as Rails' collection caching does).
      def message_views(messages)
        Messages.views(self, messages)
      end

      # ---- Sidebar

      def render_sidebar
        memberships = repo.sidebar_memberships(current_user.id)
        directs, others = memberships.partition { |_, room| room.direct? }
        directs = directs.sort_by { |_, room| room.updated_at }.reverse.map do |membership, room|
          members = repo.room_users_except(room.id, current_user.id)
          members = [ current_user ] if members.empty?
          [ membership, room, members ]
        end

        exclude = repo.member_ids_of_rooms(repo.direct_room_ids(current_user.id)).uniq + [ current_user.id ]
        placeholders = repo.active_users_excluding(exclude, [ 20 - exclude.size, 0 ].max)

        view = build_view(direct_memberships: directs, other_memberships: others, placeholder_users: placeholders)
        render_layout(view, main: view.tpl_users_sidebar)
      end

      # ---- Searches

      def render_search(query, raw_query, messages)
        fragment_page { render_search_page(query, raw_query, messages) }
      end

      def render_search_page(query, raw_query, messages)
        views = message_views(messages)
        recent = repo.recent_search_queries(current_user.id)
        return_to_room = last_room_visited
        account = runtime.account
        page_etag("search", raw_query, account.updated_at, recent, return_to_room.id, messages.map { "#{it.id}-#{it.updated_at}" })
        view = build_view(query: query, raw_query: raw_query, count: messages.size, messages: views, recent_searches: recent,
          return_to_room: return_to_room)
        view.with(recents: view.tpl_searches_recents)
        render_layout(view, page_title: "Search", body_class: "sidebar searches",
          nav: view.tpl_searches_nav, main: view.tpl_searches_index, footer: view.tpl_searches_footer, sidebar: view.tpl_searches_sidebar)
      end
    end

    # Unmatched paths get the static 404 page; a route that answers 404 itself (head :not_found) keeps its empty body.
    not_found do
      next body if env["sinatra.route"]
      # ActionDispatch::PublicExceptions: no controller ran, so none of its headers.
      without_security_headers
      without_version_headers
      response.headers.delete("X-Cascade")
      headers "Content-Type" => "text/html; charset=UTF-8"
      File.read(File.join(ROOT, "public/404.html"))
    end

    error do
      env["sinatra.error"]&.then { warn "#{it.class}: #{it.message}\n#{it.backtrace&.first(10)&.join("\n")}" }
      headers "Content-Type" => "text/html; charset=utf-8"
      status 500
      File.read(File.join(ROOT, "public/500.html"))
    end
  end
end
