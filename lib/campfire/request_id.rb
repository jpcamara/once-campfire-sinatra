require "securerandom"

module Campfire
  # ActionDispatch::RequestId and Rack::Runtime: every response that reaches the app gets an
  # X-Request-Id (the client's own, cleaned, or a new UUID) and an X-Runtime. Both sit below
  # ActionDispatch::Static in Rails, so files served from public/ get neither.
  class RequestId
    PUBLIC_FILES = %r{\A/(?:(?:404|422|500|502)\.html|robots\.txt)\z}

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) if env["PATH_INFO"].match?(PUBLIC_FILES)

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      id = request_id(env["HTTP_X_REQUEST_ID"])
      env["action_dispatch.request_id"] = id
      status, headers, body = @app.call(env)
      headers["x-request-id"] = id
      headers["x-runtime"] ||= format("%0.6f", Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
      [ status, headers, body ]
    end

    private
      def request_id(incoming)
        incoming.to_s.strip.empty? ? SecureRandom.uuid : incoming.gsub(/[^\w\-@]/, "")[0, 255]
      end
  end
end
