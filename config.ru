require_relative "lib/campfire"

Campfire.boot

# Digested assets: served straight from public/assets with Propshaft's long-lived cache headers.
assets = Rack::Files.new(File.join(__dir__, "public"), { "Cache-Control" => "public, max-age=2592000" })

app = Rack::Builder.new do
  use Campfire::Compression
  use Campfire::ETag
  map("/assets") { run ->(env) { env["PATH_INFO"] = "/assets#{env["PATH_INFO"]}"; assets.call(env) } }
  map("/cable") { run Campfire::Cable }
  run Campfire::App
end

run app
