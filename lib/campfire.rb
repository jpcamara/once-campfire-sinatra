require "json"
require "uri"
require "digest"
require "delegate"
require "net/http"

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
require_relative "campfire/view"
require_relative "campfire/broadcasts"
require_relative "campfire/messages"
require_relative "campfire/support"
require_relative "campfire/app"
require_relative "campfire/cable"
require_relative "campfire/compression"
require_relative "campfire/etag"

module Campfire
  def self.boot
    Assets.load(ROOT)
    View.compile(ROOT)
  end
end
