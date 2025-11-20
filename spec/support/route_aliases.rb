module Observ
  module TestRouteHelpers
    include Observ::Engine.routes.url_helpers

    private def translate_observ_helper(name)
      str = name.to_s
      return unless str.include?("observ_")
      str.sub("observ_", "")
    end

    def method_missing(name, *args, &block)
      translated = translate_observ_helper(name)
      return super unless translated

      engine_helpers = Observ::Engine.routes.url_helpers
      return engine_helpers.public_send(translated, *args, &block) if engine_helpers.respond_to?(translated)

      super
    rescue NoMethodError
      super
    end

    def respond_to_missing?(name, include_private = false)
      translated = translate_observ_helper(name)
      if translated
        Observ::Engine.routes.url_helpers.respond_to?(translated) || super
      else
        super
      end
    end

    def default_url_options
      {}
    end

    def _routes
      Observ::Engine.routes
    end
  end
end

RSpec.configure do |config|
  config.include Observ::TestRouteHelpers
end
