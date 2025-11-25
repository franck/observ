require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require "observ"
require "turbo-rails"

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = false
    config.root = File.expand_path("..", __dir__)
    config.secret_key_base = "dummy_secret_key_base"
    config.require_master_key = false

    # Ensure the dummy app can run engine migrations
    config.paths["db/migrate"] << File.expand_path("../../../db/migrate", __dir__)
  end
end
