require_relative "lib/campfire"

Campfire.boot
# Falcon loads this file in each worker process.
warn "campfire worker #{Process.pid}: YJIT #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? "enabled" : "disabled"}"

# Digested assets, from memory with Propshaft's long-lived cache headers.
assets = Campfire::StaticFiles.new(File.join(__dir__, "public"))

app = Rack::Builder.new do
  use Campfire::Compression
  use Campfire::ETag
  map("/assets") { run ->(env) { env["PATH_INFO"] = "/assets#{env["PATH_INFO"]}"; assets.call(env) } }
  map("/cable") { run Campfire::Cable }
  run Campfire::App
end

run app
