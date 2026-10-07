require "json"
require "uri"
require "ipaddr"
require "digest"
require "delegate"
require "net/http"
require "tempfile"

module Campfire
  # ActiveRecord::RecordInvalid from a bang method: the request answers the public 422 page.
  class RecordInvalid < StandardError; end

  # production.rb: config.assume_ssl and config.force_ssl, unless DISABLE_SSL is set.
  def self.ssl? = ENV["DISABLE_SSL"].to_s.strip.empty?

  # CAMPFIRE_CACHING=rust keeps only the caches the Rust port has: message fragments, their
  # compressed pieces and whole-body gzip, the public-response cache, prepared statements and
  # static assets. It turns off the ones only the Elixir port (or this app) has: the read cache
  # and the records built from it, kept sidebars, kept shells of room and search pages, kept
  # messages pages, remembered signatures, and memoized avatar tokens, signed blob ids,
  # signed stream names and initials. It's for measuring how much those caches are worth.
  def self.rust_caching_only? = RUST_CACHING_ONLY
  RUST_CACHING_ONLY = ENV["CAMPFIRE_CACHING"] == "rust"
end

require_relative "campfire/rails_compat"
require_relative "campfire/time_format"
require_relative "campfire/db"
require_relative "campfire/models"
require_relative "campfire/html"
require_relative "campfire/platform"
require_relative "campfire/sound"
require_relative "campfire/rich_text"
require_relative "campfire/repo"
require_relative "campfire/storage"
require_relative "campfire/attachments"
require_relative "campfire/uploads"
require_relative "campfire/translations"
require_relative "campfire/view"
require_relative "campfire/broadcasts"
require_relative "campfire/messages"
require_relative "campfire/support"
require_relative "campfire/app"
require_relative "campfire/cable"
require_relative "campfire/fragment_body"
require_relative "campfire/compression"
require_relative "campfire/response_cache"
require_relative "campfire/etag"
require_relative "campfire/unfurl"
require_relative "campfire/static_files"
require_relative "campfire/ssl"
require_relative "campfire/request_id"
require_relative "campfire/date_header"

module Campfire
  def self.boot
    Assets.load(ROOT)
    View.compile(ROOT)
  end
end
