module Observ
  class Engine < ::Rails::Engine
    isolate_namespace Observ

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: "spec/factories"
    end

    # Make concerns available to host app
    initializer "observ.load_concerns" do
      config.to_prepare do
        Dir[Observ::Engine.root.join("app", "models", "concerns", "observ", "*.rb")].each do |concern|
          require_dependency concern
        end
      end
    end

    # Asset configuration
    initializer "observ.assets" do |app|
      # Add engine assets to the asset pipeline
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/assets/stylesheets")
        app.config.assets.paths << root.join("app/assets/javascripts")
        app.config.assets.precompile += %w[ observ/application.css observ/application.js ]
      end
    end

    # Configure cache warming
    initializer "observ.configure_cache" do |app|
      config.after_initialize do
        next unless Observ.config.prompt_cache_warming_enabled

        # Warm cache asynchronously to avoid blocking boot
        Thread.new do
          sleep 2  # Wait for app to fully boot
          begin
            if defined?(Observ::PromptManager)
              Observ::PromptManager.warm_cache(Observ.config.prompt_cache_critical_prompts)
              Rails.logger.info "Observ cache warming completed"
            end
          rescue => e
            Rails.logger.error "Observ cache warming failed: #{e.message}"
          end
        end
      end
    end
  end
end
