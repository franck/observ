# frozen_string_literal: true

module Observ
  module PromptsHelper
    # Returns model options grouped by provider for use with grouped_collection_select
    # or manually building optgroups
    def chat_model_options_grouped
      return [] unless defined?(RubyLLM) && RubyLLM.respond_to?(:models)

      RubyLLM.models.chat_models
        .group_by(&:provider)
        .sort_by { |provider, _| provider }
        .map do |provider, models|
          [
            provider.titleize,
            models.sort_by(&:display_name).map { |m| [m.display_name, m.id] }
          ]
        end
    rescue StandardError => e
      Rails.logger.warn "[Observ] Failed to load RubyLLM models: #{e.message}"
      []
    end

    # Extract config value with fallback
    def config_value(prompt, key, default = nil)
      config = prompt_config_hash(prompt)
      return default unless config.is_a?(Hash)

      config[key.to_s] || config[key.to_sym] || default
    end

    private

    # Extract config hash from prompt or form object
    def prompt_config_hash(prompt)
      return {} unless prompt

      # Handle PromptForm which has config as string
      if prompt.respond_to?(:parsed_config)
        prompt.parsed_config
      elsif prompt.respond_to?(:config)
        prompt.config
      else
        {}
      end
    end
  end
end
