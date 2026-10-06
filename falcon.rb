#!/usr/bin/env -S falcon host
# frozen_string_literal: true

# `falcon serve` with Falcon's own ContentEncoding middleware left out: Compression in config.ru
# already does Thruster's gzip, and ContentEncoding only indexed every response's headers again to
# find that out.
require "etc"
require "falcon/environment/server"
require "falcon/environment/rackup"

service "campfire" do
  include Falcon::Environment::Server
  include Falcon::Environment::Rackup

  url "http://0.0.0.0:#{ENV.fetch("HTTP_PORT", 80)}"
  count ENV.fetch("WEB_CONCURRENCY") { Etc.nprocessors }.to_i

  middleware do
    ::Protocol::Rack::Adapter.new(rack_app)
  end
end
