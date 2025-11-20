# frozen_string_literal: true

Rails.application.configure do
  config.observability = ActiveSupport::OrderedOptions.new
  config.observability.enabled = true
  config.observability.auto_instrument_chats = true
  config.observability.debug = false
end
