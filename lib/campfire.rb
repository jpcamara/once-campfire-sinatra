require "json"
require "uri"
require "ipaddr"
require "digest"
require "delegate"
require "net/http"
require "tempfile"

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

module Campfire
  # ActiveRecord::RecordInvalid from a bang method: the request answers the public 422 page.
  class RecordInvalid < StandardError; end

  # production.rb: config.assume_ssl and config.force_ssl, unless DISABLE_SSL is set.
  def self.ssl? = ENV["DISABLE_SSL"].to_s.strip.empty?

  def self.boot
    Assets.load(ROOT)
    View.compile(ROOT)
  end
end
