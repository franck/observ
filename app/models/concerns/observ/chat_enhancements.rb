# frozen_string_literal: true

module Observ
  # Concern for enhancing Chat models with observability and agent support
  # This provides the integration between your Chat model and the Observ system
  #
  # Usage:
  #   class Chat < ApplicationRecord
  #     include Observ::ChatEnhancements
  #
  #     # Optional: Define agent_class method if using agents
  #     def agent_class
  #       return BaseAgent if agent_class_name.blank?
  #       agent_class_name.constantize
  #     end
  #   end
  module ChatEnhancements
    extend ActiveSupport::Concern

    included do
      include Observ::ObservabilityInstrumentation

      # Set the model from agent BEFORE RubyLLM's resolve_model_from_strings runs
      # This ensures the prompt version override is applied when determining the model
      before_save :set_model_from_agent, if: -> { respond_to?(:agent_class_name) && agent_class_name.present? }

      # Initialize agent on creation (includes greeting message)
      after_create :initialize_agent_on_create, if: -> { respond_to?(:agent_class_name) && agent_class_name.present? }
    end

    # Setup tools for the chat session
    # Override this in your Chat model if you need custom tool setup
    def setup_tools
      return unless respond_to?(:agent_class)
      agent_class.setup_tools(self)
    end

    # Ensure agent parameters are set when needed
    # This is called lazily when the chat is actually used
    #
    # Note: Instructions are already set in initialize_agent_on_create (after_create callback)
    # and should NOT be re-applied on every message. Only parameters need to be re-set
    # because they are lost when the chat is reloaded from the database.
    def ensure_agent_configured
      return unless respond_to?(:agent_class) && agent_class_name.present?
      return if @_agent_params_configured

      # Set prompt version override if specified
      if respond_to?(:prompt_version) && prompt_version.present? &&
         agent_class.included_modules.include?(Observ::PromptManagement)
        Thread.current[:observ_prompt_version_override] = prompt_version
      end

      begin
        # Only re-apply parameters, not instructions
        # Instructions were already set at creation time
        agent_class.setup_parameters(self)
        @_agent_params_configured = true
      ensure
        Thread.current[:observ_prompt_version_override] = nil
      end
    end

    private

    # Set the model from agent configuration before save
    # This runs BEFORE RubyLLM's resolve_model_from_strings callback,
    # ensuring the correct model is used when a specific prompt version is specified
    def set_model_from_agent
      return unless respond_to?(:agent_class)

      # Set prompt version override if specified and agent supports prompt management
      if respond_to?(:prompt_version) && prompt_version.present? &&
         agent_class.included_modules.include?(Observ::PromptManagement)
        Thread.current[:observ_prompt_version_override] = prompt_version
      end

      begin
        # Set the model string so RubyLLM's resolve_model_from_strings uses the correct model
        # This uses the agent's model method which respects the prompt version override
        @model_string = agent_class.model
      ensure
        Thread.current[:observ_prompt_version_override] = nil
      end
    end

    def initialize_agent_on_create
      return unless respond_to?(:agent_class)

      # If chat has a specific prompt version, temporarily set it for setup
      if respond_to?(:prompt_version) && prompt_version.present? &&
         agent_class.included_modules.include?(Observ::PromptManagement)
        # Store the version temporarily so setup_instructions can use it
        Thread.current[:observ_prompt_version_override] = prompt_version
      end

      begin
        # Execute all agent setup steps in one consolidated callback
        # This prevents redundant association loading between callbacks
        agent_class.setup_instructions(self)
        agent_class.setup_parameters(self)
        agent_class.send_initial_greeting(self)
      ensure
        # Clean up thread-local storage
        Thread.current[:observ_prompt_version_override] = nil
      end
    end
  end
end
