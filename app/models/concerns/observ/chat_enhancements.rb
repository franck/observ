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

      # Consolidated callback for agent initialization to reduce redundant queries
      # Only runs if the including model has an agent_class_name attribute
      after_create :initialize_agent, if: -> { respond_to?(:agent_class_name) && agent_class_name.present? }
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

    private

    def initialize_agent
      return unless respond_to?(:agent_class)

      # Execute both agent setup steps in one consolidated callback
      # This prevents redundant association loading between callbacks
      agent_class.setup_instructions(self)
      agent_class.send_initial_greeting(self)
    end
  end
end
