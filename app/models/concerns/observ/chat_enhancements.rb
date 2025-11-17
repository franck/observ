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

      # Initialize agent on creation (includes greeting message)
      after_create :initialize_agent_on_create, if: -> { respond_to?(:agent_class_name) && agent_class_name.present? }
    end

    # Override observability_context to include agent_class if available
    # This allows the ChatInstrumenter to extract prompt metadata
    def observability_context
      context = super

      # Include agent_class if available for prompt metadata extraction
      if respond_to?(:agent_class)
        context[:agent_class] = agent_class
      end

      context
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

      # Only re-apply parameters, not instructions
      # Instructions were already set at creation time
      agent_class.setup_parameters(self)
      @_agent_params_configured = true
    end

    private

    def initialize_agent_on_create
      return unless respond_to?(:agent_class)

      # Execute all agent setup steps in one consolidated callback
      # This prevents redundant association loading between callbacks
      agent_class.setup_instructions(self)
      agent_class.setup_parameters(self)
      agent_class.send_initial_greeting(self)
    end
  end
end
