require_relative "lib/campfire"

Campfire.boot

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
