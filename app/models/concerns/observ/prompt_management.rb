# frozen_string_literal: true

module Observ
  # Concern for agents that want to use the prompt management system
  # Provides functionality to fetch prompts from the database with fallback support,
  # caching, variable interpolation, and model configuration from prompt metadata.
  #
  # Usage:
  #   class MyAgent < BaseAgent
  #     include Observ::PromptManagement
  #
  #     FALLBACK_PROMPT = "You are a helpful assistant."
  #
  #     use_prompt_management(
  #       prompt_name: "my-agent-system-prompt",
  #       fallback: FALLBACK_PROMPT
  #     )
  #
  #     def self.default_model
  #       "gpt-4.1-nano"
  #     end
  #   end
  module PromptManagement
    extend ActiveSupport::Concern

    included do
      class_attribute :prompt_config, default: {}
      # Cache the fetched prompt template object for metadata access
      class_attribute :cached_prompt_template, default: nil
      # Instance variable for version override (set per instance, not shared across class)
      attr_accessor :prompt_version_override
    end

    class_methods do
      # Enable/disable prompt management per agent
      def use_prompt_management(enabled: true, prompt_name: nil, fallback: nil)
        self.prompt_config = {
          enabled: enabled,
          prompt_name: prompt_name || default_prompt_name,
          fallback: fallback || default_fallback_prompt
        }
      end

      # Default prompt name based on agent class name
      def default_prompt_name
        name.underscore.tr("_/", "--") + "-system-prompt"
        # Example: ResearchAgent => 'research-agent-system-prompt'
      end

      # Override in subclasses if needed
      def default_fallback_prompt
        "You are a helpful AI assistant."
      end

      # Check if prompt management is enabled for this agent
      def prompt_management_enabled?
        Observ.config.prompt_management_enabled &&
        prompt_config[:enabled] != false
      end

      # Fetch prompt with fallback
      # Supports version override via thread-local storage or parameter
      def fetch_prompt(variables: {}, version: nil)
        # Ensure defaults if prompt_config was never initialized
        config = prompt_config.presence || {}
        fallback = config[:fallback] || default_fallback_prompt
        prompt_name = config[:prompt_name] || default_prompt_name

        return fallback unless prompt_management_enabled?

        start_time = Time.current

        begin
          # Check for version override from thread-local storage or parameter
          version_to_use = Thread.current[:observ_prompt_version_override] || version

          # Fetch prompt with version or state
          if version_to_use.present?
            prompt_template = Observ::PromptManager.fetch(
              name: prompt_name,
              version: version_to_use,
              fallback: fallback
            )
          else
            prompt_template = Observ::PromptManager.fetch(
              name: prompt_name,
              state: :production,
              fallback: fallback
            )
          end

          # Cache the template for metadata access
          @_prompt_template = prompt_template

          # Log fetch result
          duration_ms = ((Time.current - start_time) * 1000).round(2)
          if prompt_template.version
            version_info = version_to_use.present? ? "(version: #{prompt_template.version})" : "(production, version: #{prompt_template.version})"
            Rails.logger.info(
              "Prompt fetched for #{name}: #{prompt_name} " \
              "#{version_info}, " \
              "duration: #{duration_ms}ms)"
            )
          else
            Rails.logger.info(
              "Using fallback prompt for #{name}: prompt '#{prompt_name}' not found " \
              "(duration: #{duration_ms}ms)"
            )
          end

          # Compile with variables (works for both Prompt and NullPrompt)
          if variables.any?
            prompt_template.compile(variables)
          else
            prompt_template.prompt
          end
        rescue => e
          Rails.logger.error(
            "Failed to fetch prompt for #{name}: #{e.message}\n" \
            "#{e.backtrace.first(5).join("\n")}"
          )
          # Clear cached template on error
          @_prompt_template = nil
          fallback
        end
      end

      # Override this in subclasses to provide dynamic variables
      def prompt_variables
        {
          current_date: Time.current.strftime("%B %d, %Y"),
          current_time: Time.current.strftime("%I:%M %p %Z")
        }
      end

      # Override system_prompt to use prompt management
      def system_prompt
        @_system_prompt ||= fetch_prompt(variables: prompt_variables)
      end

      # Get the cached prompt template (with name and version)
      def current_prompt_template
        @_prompt_template
      end

      # Get prompt metadata for observability
      # @return [Hash] Hash with :prompt_name and :prompt_version keys
      def prompt_metadata
        template = current_prompt_template
        return {} unless template

        {
          prompt_name: template.respond_to?(:name) ? template.name : nil,
          prompt_version: template.respond_to?(:version) ? template.version : nil
        }.compact
      end

      # Clear cached prompt (useful for tests or when prompt is updated)
      def reset_prompt_cache!
        @_system_prompt = nil
        @_prompt_template = nil
      end

      # Override model to check prompt metadata first
      # Priority:
      # 1. Prompt metadata (config['model']) - if prompt management is enabled
      # 2. Agent's default_model - fallback
      def model
        # Check if prompt has model in metadata
        if prompt_management_enabled?
          model_from_prompt = fetch_model_from_prompt
          return model_from_prompt if model_from_prompt.present?
        end

        # Fallback to agent's default
        default_model
      end

      # Fetch model from prompt metadata
      # @return [String, nil] The model from prompt config, or nil
      def fetch_model_from_prompt(version: nil)
        return nil unless prompt_management_enabled?

        config = prompt_config.presence || {}
        fallback = config[:fallback] || default_fallback_prompt
        prompt_name = config[:prompt_name] || default_prompt_name

        begin
          # Check for version override from thread-local storage or parameter
          version_to_use = Thread.current[:observ_prompt_version_override] || version

          # Fetch prompt with version or state
          if version_to_use.present?
            prompt_template = Observ::PromptManager.fetch(
              name: prompt_name,
              version: version_to_use,
              fallback: fallback
            )
          else
            prompt_template = Observ::PromptManager.fetch(
              name: prompt_name,
              state: :production,
              fallback: fallback
            )
          end

          # If we got a real Prompt object (not NullPrompt), check its config
          if prompt_template.respond_to?(:config) && prompt_template.config.is_a?(Hash)
            prompt_template.config["model"]
          end
        rescue => e
          Rails.logger.debug(
            "Could not fetch model from prompt #{prompt_name}: #{e.message}"
          )
          nil
        end
      end

      # Override model_parameters to check prompt metadata first
      # Priority:
      # 1. Prompt metadata (config['temperature'], config['max_tokens'], etc.)
      # 2. Agent's default_model_parameters - fallback
      # @return [Hash] The model parameters to use
      def model_parameters
        # Check if prompt has parameters in metadata
        if prompt_management_enabled?
          params_from_prompt = fetch_model_parameters_from_prompt
          return params_from_prompt if params_from_prompt.present?
        end

        # Fallback to agent's defaults
        default_model_parameters
      end

      # Fetch model parameters from prompt metadata
      # @return [Hash] The model parameters from prompt config
      def fetch_model_parameters_from_prompt(version: nil)
        return {} unless prompt_management_enabled?

        config = prompt_config.presence || {}
        fallback = config[:fallback] || default_fallback_prompt
        prompt_name = config[:prompt_name] || default_prompt_name

        begin
          # Check for version override from thread-local storage or parameter
          version_to_use = Thread.current[:observ_prompt_version_override] || version

          # Fetch prompt with version or state
          if version_to_use.present?
            prompt_template = Observ::PromptManager.fetch(
              name: prompt_name,
              version: version_to_use,
              fallback: fallback
            )
          else
            prompt_template = Observ::PromptManager.fetch(
              name: prompt_name,
              state: :production,
              fallback: fallback
            )
          end

          # If we got a real Prompt object (not NullPrompt), extract parameters
          if prompt_template.respond_to?(:config) && prompt_template.config.is_a?(Hash)
            extract_llm_parameters(prompt_template.config)
          else
            {}
          end
        rescue => e
          Rails.logger.debug(
            "Could not fetch parameters from prompt #{prompt_name}: #{e.message}"
          )
          {}
        end
      end

      private

      # Extract LLM parameters from config hash
      # @param config [Hash] The prompt config
      # @return [Hash] Extracted parameters (temperature, max_tokens, etc.)
      def extract_llm_parameters(config)
        params = config.slice(
          "temperature",
          "max_tokens",
          "top_p",
          "frequency_penalty",
          "presence_penalty",
          "stop",
          "response_format",
          "seed"
        ).transform_keys(&:to_sym).compact

        # Convert string numbers to proper types (JSON returns strings)
        params.transform_values do |value|
          convert_to_numeric_if_needed(value)
        end
      end

      # Convert string numbers to proper numeric types
      # @param value [Object] The value to convert
      # @return [Object] Converted value (or original if not a numeric string)
      def convert_to_numeric_if_needed(value)
        case value
        when String
          # Check if it's a numeric string (integer or float)
          if value.match?(/\A-?\d+\.\d+\z/)
            value.to_f
          elsif value.match?(/\A-?\d+\z/)
            value.to_i
          else
            value
          end
        else
          value
        end
      end
    end
  end
end
