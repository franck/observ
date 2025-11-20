# frozen_string_literal: true

# Base interface for all agents in test suite
# This is a copy of the template from lib/generators/observ/install_chat/templates/agents/base_agent.rb.tt
#
# Note: This duplication is intentional - BaseAgent is meant to be owned by each host application,
# not shipped as part of the gem. The test suite needs its own copy to test agent functionality.
#
# Defines the contract that all agents must implement
#
# Responsibilities:
#   - Define required interface methods (system_prompt, default_model)
#   - Define optional interface methods (tools, initial_greeting)
#   - Provide setup methods that work with the interface
#
# Usage:
#   class MyAgent < BaseAgent
#     def self.system_prompt
#       "You are a helpful assistant."
#     end
#
#     def self.default_model
#       "gpt-4o-mini"
#     end
#
#     def self.tools
#       [MyTool]
#     end
#   end
#
# For agents that want prompt management, include the Observ::PromptManagement concern:
#   class MyAgent < BaseAgent
#     include Observ::PromptManagement
#     # ...
#   end
class BaseAgent
  # ============================================
  # INTERFACE METHODS - Override in subclasses
  # ============================================

  # System prompt for the agent
  # @return [String] The system prompt
  def self.system_prompt
    raise NotImplementedError, "#{name} must implement .system_prompt"
  end

  # Default model for this agent
  # @return [String] The default model identifier
  def self.default_model
    raise NotImplementedError, "#{name} must implement .default_model"
  end

  # Tools available to this agent
  # @return [Array<Class>] Array of tool classes
  def self.tools
    []
  end

  # Initial greeting message when chat starts
  # @return [String, nil] The greeting message or nil
  def self.initial_greeting
    nil
  end

  # Model to use for this agent
  # Can be overridden by concerns (e.g., Observ::PromptManagement)
  # @return [String] The model identifier to use
  def self.model
    default_model
  end

  # Default model parameters for this agent (temperature, max_tokens, etc.)
  # @return [Hash] Hash of model parameters
  def self.default_model_parameters
    {}  # Override in subclasses for custom defaults
  end

  # Model parameters to use for this agent
  # Can be overridden by concerns (e.g., Observ::PromptManagement)
  # @return [Hash] The model parameters to use
  def self.model_parameters
    default_model_parameters
  end

  # ============================================
  # SETUP METHODS - Work with the interface
  # ============================================

  # Setup instructions for the chat session
  # @param chat [Chat] The chat session
  # @return [Chat] The configured chat session
  def self.setup_instructions(chat)
    chat.with_instructions(system_prompt) if system_prompt.present?
    chat
  end

  # Setup tools for the chat session
  # @param chat [Chat] The chat session
  # @return [Chat] The configured chat session
  def self.setup_tools(chat)
    if tools.any?
      instantiated_tools = tools.map do |tool|
        if tool.instance_of?(Class)
          observ_session = chat.observ_session if chat.respond_to?(:observ_session)
          tool.new(observ_session)
        else
          if tool.respond_to?(:observability=) && chat.respond_to?(:observ_session)
            tool.observability = chat.observ_session
          end
          tool
        end
      end
      chat.with_tools(*instantiated_tools)
    end
    chat
  end

  # Setup model parameters for the chat session
  # @param chat [Chat] The chat session
  # @return [Chat] The configured chat session
  def self.setup_parameters(chat)
    params = model_parameters

    # Convert string numeric values to proper types for API compatibility
    # This is necessary because prompt configs may return string values
    normalized_params = params.transform_values do |value|
      case value
      when String
        # Convert numeric strings to numbers
        if value.match?(/\A-?\d+\.?\d*\z/)
          value.include?('.') ? value.to_f : value.to_i
        else
          value
        end
      else
        value
      end
    end

    chat.with_params(**normalized_params) if normalized_params.any?
    chat
  end

  # Send initial greeting message
  # @param chat [Chat] The chat session
  def self.send_initial_greeting(chat)
    return unless initial_greeting

    chat.messages.create!(
      role: :assistant,
      content: initial_greeting
    )
  end
end
