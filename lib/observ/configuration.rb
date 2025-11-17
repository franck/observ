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
                  :back_to_app_path,
                  :back_to_app_label,
                  :chat_ui_enabled,
                  :agent_path

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
      @back_to_app_path = -> { "/" }
      @back_to_app_label = "← Back to App"
      @chat_ui_enabled = -> { defined?(::Chat) && ::Chat.respond_to?(:acts_as_chat) }
      @agent_path = nil # Defaults to Rails.root.join("app", "agents")
    end

    # Check if chat UI is enabled
    # @return [Boolean]
    def chat_ui_enabled?
      return @chat_ui_enabled.call if @chat_ui_enabled.respond_to?(:call)
      @chat_ui_enabled
    end
  end
end
