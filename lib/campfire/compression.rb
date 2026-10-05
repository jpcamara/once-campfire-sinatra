require "zlib"

module Campfire
  # gzip for text responses, at zlib's default level (what Rack::Deflater and Thruster use).
  class Compression
    TYPES = %r{\A(text/|application/(json|javascript|manifest\+json)|image/svg\+xml)}
    MINIMUM_SIZE = 860

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      return [ status, headers, body ] unless compressible?(env, status, headers)

      if body.is_a?(FragmentBody)
        compressed = body.gzip
      else
        content = +""
        body.each { content << it }
        body.close if body.respond_to?(:close)
        return [ status, headers, [ content ] ] if content.bytesize < MINIMUM_SIZE

        compressed = Zlib::Deflate.new(Zlib::DEFAULT_COMPRESSION, Zlib::MAX_WBITS + 16).deflate(content, Zlib::FINISH)
      end
      headers["content-encoding"] = "gzip"
      headers["content-length"] = compressed.bytesize.to_s
      headers["vary"] = [ headers["vary"], "Accept-Encoding" ].compact.join(",")
      [ status, headers, [ compressed ] ]
    end

    private
      def compressible?(env, status, headers)
        status == 200 && env["HTTP_ACCEPT_ENCODING"].to_s.include?("gzip") && !headers["content-encoding"] &&
          headers["content-type"].to_s.match?(TYPES) && !headers.key?("content-range")
      end
  end
end
