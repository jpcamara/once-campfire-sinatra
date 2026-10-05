require "erubi"
require "base64"
require "zlib"

module Campfire
  # Request-scoped rendering context. Each template under views/ compiles once, at boot, into a
  # `render_<path>` method on this class that returns a String; `<%= %>` escapes, `<%== %>` doesn't.
  class View
    REACTIONS = {
      "👍" => "Thumbs up", "👏" => "Clapping", "👋" => "Waving hand", "💪" => "Muscle",
      "❤️" => "Red heart", "😂" => "Face with tears of joy", "🎉" => "Party popper", "🔥" => "Fire"
    }.freeze

    TRANSLATIONS = {
      email_address: { "🇺🇸": "Enter your email address", "🇪🇸": "Introduce tu correo electrónico", "🇫🇷": "Entrez votre adresse courriel", "🇮🇳": "अपना ईमेल पता दर्ज करें", "🇩🇪": "Geben Sie Ihre E-Mail-Adresse ein", "🇧🇷": "Insira seu endereço de email", "🇯🇵": "メールアドレスを入力してください" },
      password: { "🇺🇸": "Enter your password", "🇪🇸": "Introduce tu contraseña", "🇫🇷": "Saisissez votre mot de passe", "🇮🇳": "अपना पासवर्ड दर्ज करें", "🇩🇪": "Geben Sie Ihr Passwort ein", "🇧🇷": "Insira sua senha", "🇯🇵": "パスワードを入力してください" },
      invite_message: { "🇺🇸": "Welcome to Campfire. To invite some people to chat with you, share the join link below.", "🇪🇸": "Bienvenido a Campfire. Para invitar a algunas personas a chatear contigo, comparte el enlace de unión que se encuentra a continuación.", "🇫🇷": "Bienvenue sur Campfire. Pour inviter des personnes à discuter avec vous, partagez le lien pour rejoindre ci-dessous.", "🇮🇳": "Campfire में आपका स्वागत है। अधिक लोगों को चैट के लिए आमंत्रित करने के लिए, नीचे जुड़ने का लिंक साझा करें।", "🇩🇪": "Willkommen bei Campfire. Um einige Personen zum Chatten einzuladen, teilen Sie den unten stehenden Beitrittslink.", "🇧🇷": "Boas vindas ao Campfire. Para convidar pessoas para conversarem com você, compartilhe o link de convite abaixo.", "🇯🇵": "Campfireへようこそ。他の人をチャットに招待するには、下記の参加リンクを共有してください。" }
    }.freeze

    AVATAR_COLORS = %w[ #AF2E1B #CC6324 #3B4B59 #BFA07A #ED8008 #ED3F1C #BF1B1B #736B1E #D07B53
      #736356 #AD1D1D #BF7C2A #C09C6F #698F9C #7C956B #5D618F #3B3633 #67695E ].freeze

    def self.compile(root)
      Dir[File.join(root, "views/**/*.erb")].sort.each do |file|
        name = file.delete_prefix(File.join(root, "views/")).delete_suffix(".erb").tr("/", "_")
        src = Erubi::Engine.new(File.read(file), escape: true, freeze_template_literals: false, bufvar: "_buf").src
        class_eval "def tpl_#{name}\n#{src}\nend", file, 0
      end
    end

    attr_reader :app, :current_user, :base_url, :flash, :request

    def initialize(app:, current_user: nil, base_url:, user_agent: nil, flash: {})
      @app, @current_user, @base_url, @user_agent, @flash = app, current_user, base_url, user_agent, flash
    end

    # Templates read their locals through method_missing-free accessors set here.
    def with(**locals)
      locals.each { |name, value| instance_variable_set(:"@#{name}", value) }
      self
    end

    def h(value) = HTML.h(value)
    def asset_path(logical) = Assets.path(logical)
    def platform = (@platform ||= Platform.new(@user_agent))
    def account = app.account
    def vapid_public_key = app.vapid_public_key
    def app_version = app.app_version
    def secrets = app.secrets

    def capitalize(value)
      value.to_s.capitalize
    end

    def image_tag(source, size: nil, **attrs)
      width = height = size
      HTML.void_tag("img", **attrs, src: asset_path(source), width: width, height: height)
    end

    def body_classes
      [ @body_class, ("admin" if current_user&.can_administer?), ("account-has-logo" if account_logo_attached?) ].compact.join(" ")
    end

    def account_logo_attached?
      app.account_logo_attached?
    end

    def account_logo_path
      "/account/logo?v=#{TimeFormat.number(account.updated_at)}"
    end

    def account_logo_tag(style: nil)
      %(<figure class="account-logo avatar #{style}"><img alt="Account logo" src="#{account_logo_path}" width="300" height="300" /></figure>)
    end

    def avatar_token(user)
      app.avatar_token(user.id)
    end

    def avatar_path(user)
      "/users/#{avatar_token(user)}/avatar?v=#{TimeFormat.number(user.updated_at)}"
    end

    def avatar_tag(user, aria_label: nil)
      aria = aria_label ? %(aria-label="#{h aria_label}") : %(aria-hidden="true")
      %(<a title="#{h user.title}" class="btn avatar" data-turbo-frame="_top" href="/users/#{user.id}"><img #{aria} src="#{avatar_path(user)}" width="48" height="48" /></a>)
    end

    def avatar_background_color(user)
      AVATAR_COLORS[Zlib.crc32(user.to_param) % AVATAR_COLORS.size]
    end

    def turbo_stream_from_tag(channel, name)
      %(<turbo-cable-stream-source channel="#{channel}" signed-stream-name="#{h secrets.signed_stream_name(name)}"></turbo-cable-stream-source>)
    end

    def room_display_name(room, for_user = current_user)
      if room.direct?
        names = app.repo.direct_room_member_names(room.id, for_user&.id)
        names.empty? ? for_user&.name : to_sentence(names)
      else
        room.name
      end
    end

    def to_sentence(words, two_words_connector: " and ")
      case words.size
      when 0 then ""
      when 1 then words[0].to_s
      when 2 then "#{words[0]}#{two_words_connector}#{words[1]}"
      else "#{words[0...-1].join(", ")}, and #{words[-1]}"
      end
    end

    def all_emoji?(text)
      app.all_emoji?(text)
    end

    def url_encode_query(value)
      URI.encode_www_form_component(value)
    end

    def translation_button(key)
      items = TRANSLATIONS.fetch(key).map { |language, text| %(<dt>#{language}</dt><dd class="margin-none">#{h text}</dd>) }.join
      %(<details class="position-relative" data-controller="popup" data-action="keydown.esc-&gt;popup#close toggle-&gt;popup#toggle click@document-&gt;popup#closeOnClickOutside" data-popup-orientation-top-class="popup-orientation-top"><summary class="btn" tabindex="-1"><img aria-hidden="true" class="color-icon" src="#{asset_path "globe.svg"}" width="20" height="20" /><span class="for-screen-reader">Translate</span></summary><div class="language-list-menu shadow" data-popup-target="menu"><dl class="language-list">#{items}</dl></div></details>)
    end

    def first_administrator
      app.repo.first_administrator
    end

    def blob_path(blob, disposition: nil)
      app.blob_path(blob, disposition: disposition)
    end

    # The message partial, cached per message version and host like Rails' fragment cache.
    def render_message_cached(view)
      app.fragment_cache.fetch([ view.message.id, view.message.updated_at, base_url ]) { render_message(view) }
    end

    UNRENDERABLE = <<~HTML.freeze
      <div class="message message--formatted message--failed center">
        <div class="message__body">
          <div class="message__body-content txt-align-center">
            Failed to load message content
          </div>
        </div>
      </div>
    HTML

    # MessagesHelper#message_tag rescues any failure into the unrenderable placeholder.
    def render_message(view)
      scoped(view: view, message: view.message, creator: view.creator, room: view.room) { tpl_messages_message }
    rescue Exception => error
      warn "Exception while rendering message Message##{view.message.id}, failed with: #{error.class} `#{error.message}`"
      UNRENDERABLE
    end

    def render_message_actions(view) = tpl_messages_actions
    def render_boosts(view) = tpl_messages_boosts

    def render_boost(boost, booster)
      scoped(boost: boost, booster: booster) { tpl_messages_boost }
    end

    def render_bell(room)
      scoped(room: room) { tpl_rooms_bell }
    end

    def render_sidebar_direct(membership, room, members)
      scoped(membership: membership, room: room, members: members) { tpl_users_sidebar_direct }
    end

    def render_messages_template = tpl_messages_template
    def render_lightbox = tpl_layouts_lightbox
    def render_pwa_browser_settings = tpl_pwa_browser_settings
    def render_pwa_system_settings = tpl_pwa_system_settings
    def render_pwa_install_instructions = tpl_pwa_install_instructions
    def render_invitation = tpl_rooms_invitation
    def render_invite = tpl_rooms_invite
    def render_help_contact = tpl_sessions_help_contact

    # Sets locals for one partial and restores the caller's afterwards.
    def scoped(**locals)
      saved = locals.keys.to_h { [ it, instance_variable_get(:"@#{it}") ] }
      locals.each { |name, value| instance_variable_set(:"@#{name}", value) }
      yield
    ensure
      saved.each { |name, value| instance_variable_set(:"@#{name}", value) }
    end

    # Locals the templates use.
    attr_reader :message, :creator, :room, :view, :boost, :booster, :membership, :members, :messages, :invitation,
      :direct_memberships, :other_memberships, :placeholder_users, :query, :raw_query, :count, :recents, :recent_searches,
      :return_to_room, :email_address
  end
end
