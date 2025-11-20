require_relative "application"

Rails.env ||= ENV.fetch("RAILS_ENV", "test")
Rails.application.initialize!
