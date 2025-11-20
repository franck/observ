# frozen_string_literal: true

module Observ
  class Configuration
    attr_accessor :prompt_management_enabled,
                  :prompt_cache_ttl,
                  :prompt_fallback_behavior,
                  :prompt_cache_store,
                  :prompt_cache_prefix,
                  :prompt_cache_namespace,
                  :prompt_max_versions,
                  :prompt_default_state,
                  :prompt_allow_production_deletion,
                  :prompt_cache_warming_enabled,
                  :prompt_cache_critical_prompts,
                  :prompt_cache_monitoring_enabled,
                  :prompt_config_schema,
                  :prompt_config_schema_strict,
                  :back_to_app_path,
                  :back_to_app_label,
                  :chat_ui_enabled,
                  :agent_path,
                  :pagination_per_page

    def initialize
      @prompt_management_enabled = true
      @prompt_cache_ttl = 300 # 5 minutes
      @prompt_fallback_behavior = :raise # or :return_nil, :use_fallback
      @prompt_cache_store = :redis_cache_store
      @prompt_cache_prefix = "observ:prompt"
      @prompt_cache_namespace = "observ:prompt"
      @prompt_max_versions = 100
      @prompt_default_state = :production
      @prompt_allow_production_deletion = false
      @prompt_cache_warming_enabled = true
      @prompt_cache_critical_prompts = []
      @prompt_cache_monitoring_enabled = true
      @prompt_config_schema = default_prompt_config_schema
      @prompt_config_schema_strict = false
      @back_to_app_path = -> { "/" }
      @back_to_app_label = "← Back to App"
      @chat_ui_enabled = -> { defined?(::Chat) && ::Chat.respond_to?(:acts_as_chat) }
      @agent_path = nil # Defaults to Rails.root.join("app", "agents")
      @pagination_per_page = 25
    end

    # Check if chat UI is enabled
    # @return [Boolean]
    def chat_ui_enabled?
      return @chat_ui_enabled.call if @chat_ui_enabled.respond_to?(:call)
      @chat_ui_enabled
    end

    # Default schema for prompt configuration validation
    # @return [Hash]
    def default_prompt_config_schema
      {
        temperature: {
          type: :float,
          required: false,
          range: 0.0..2.0,
          default: 0.7
        },
        max_tokens: {
          type: :integer,
          required: false,
          range: 1..100000
        },
        top_p: {
          type: :float,
          required: false,
          range: 0.0..1.0
        },
        frequency_penalty: {
          type: :float,
          required: false,
          range: -2.0..2.0
        },
        presence_penalty: {
          type: :float,
          required: false,
          range: -2.0..2.0
        },
        stop_sequences: {
          type: :array,
          required: false,
          item_type: :string
        },
        model: {
          type: :string,
          required: false
        },
        response_format: {
          type: :hash,
          required: false
        },
        seed: {
          type: :integer,
          required: false
        },
        stream: {
          type: :boolean,
          required: false
        }
      }
    end
  end
end
