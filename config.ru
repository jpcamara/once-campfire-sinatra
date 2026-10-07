require_relative "lib/campfire"

Campfire.boot
# Falcon loads this file in each worker process.
warn "campfire worker #{Process.pid}: YJIT #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? "enabled" : "disabled"}"

# Digested assets, from memory with Propshaft's long-lived cache headers.
assets = Campfire::StaticFiles.new(File.join(__dir__, "public"))

# Everything Rails' router reaches: ActionDispatch::RequestId and Rack::Runtime, then the app or cable.
rails = Campfire::RequestId.new(lambda do |env|
  env["PATH_INFO"] == "/cable" ? Campfire::Cable.call(env) : Campfire::App.call(env)
end)

# Built once: a Rack::Builder used as the app would build the whole stack again on every request
# (and the middlewares' kept state with it).
app = Rack::Builder.app do
  use Campfire::DateHeader
  use Campfire::SSL if Campfire.ssl?
  use Campfire::ResponseCache
  use Campfire::Compression
  use Campfire::ETag
  # Assets by prefix (Rack::URLMap matched a regexp per mapping per request).
  run(lambda do |env|
    path = env["PATH_INFO"]
    if path.start_with?("/assets/") then assets.call(env)
    else rails.call(env)
    end
  end)
end

run app
