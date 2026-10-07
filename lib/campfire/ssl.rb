module Campfire
  # config.assume_ssl and config.force_ssl, which production.rb sets unless DISABLE_SSL is:
  # ActionDispatch::AssumeSSL treats every request as HTTPS (TLS ends in front of the app), and
  # ActionDispatch::SSL adds HSTS and marks every cookie Secure. With every request taken as HTTPS,
  # force_ssl's redirect never fires.
  class SSL
    HSTS = "max-age=63072000; includeSubDomains"
    SECURE = /;\s*secure\s*(;|$)/i

    def initialize(app)
      @app = app
    end

    def call(env)
      env["HTTPS"] = "on"
      env["HTTP_X_FORWARDED_PORT"] = "443"
      env["HTTP_X_FORWARDED_PROTO"] = "https"
      env["rack.url_scheme"] = "https"

      status, headers, body = @app.call(env)
      headers["strict-transport-security"] ||= HSTS
      if (cookies = headers["set-cookie"])
        headers["set-cookie"] = secure_cookies(cookies)
      end
      [ status, headers, body ]
    end

    private
      def secure_cookies(cookies)
        lines = cookies.is_a?(Array) ? cookies : cookies.split("\n")
        secured = lines.map { it.match?(SECURE) ? it : "#{it}; secure" }
        cookies.is_a?(Array) ? secured : secured.join("\n")
      end
  end
end
