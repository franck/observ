# frozen_string_literal: true

module Observ
  # Generic service for executing any agent against an input
  #
  # This service encapsulates the RubyLLM chat configuration and execution pattern,
  # providing a unified way to run agents for dataset evaluations or other purposes.
  #
  # The service:
  # - Creates a RubyLLM chat with the agent's model
  # - Applies system prompt, schema, and model parameters
  # - Optionally instruments the chat for observability
  # - Handles both simple text input and structured context hashes
  #
  # Usage:
  #   # Basic usage
  #   executor = Observ::AgentExecutorService.new(LanguageDetectionAgent)
  #   result = executor.call("Hello, how are you?")
  #
  #   # With observability
  #   session = Observ::Session.create!(user_id: "user_123")
  #   executor = Observ::AgentExecutorService.new(
  #     LanguageDetectionAgent,
  #     observability_session: session
  #   )
  #   result = executor.call("Bonjour!")
  #
  #   # With context hash (for agents that implement build_user_prompt)
  #   executor = Observ::AgentExecutorService.new(CharacterGeneratorAgent)
  #   result = executor.call(genre: "fantasy", title: "Dragon Quest")
  #
  class AgentExecutorService
    class ExecutionError < StandardError; end
    class RubyLLMNotAvailableError < ExecutionError; end

    attr_reader :agent_class, :observability_session

    # Initialize the executor
    #
    # @param agent_class [Class] The agent class to execute (must respond to model, system_prompt)
    # @param observability_session [Observ::Session, nil] Optional session for tracing
    # @param context [Hash] Additional context metadata for tracing
    def initialize(agent_class, observability_session: nil, context: {})
      @agent_class = agent_class
      @observability_session = observability_session
      @context = context

      validate_ruby_llm_available!
      validate_agent_class!
    end

    # Execute the agent with the given input
    #
    # @param input [String, Hash] The input text or context hash
    # @return [Hash, String] The agent's response (structured if schema defined, string otherwise)
    # @raise [ExecutionError] If the agent execution fails
    def call(input)
      chat = build_chat
      configure_chat(chat)
      instrument_chat(chat) if observability_session

      user_prompt = build_user_prompt(input)
      response = chat.ask(user_prompt)

      normalize_response(response.content)
    rescue StandardError => e
      raise ExecutionError, "Agent execution failed: #{e.message}"
    end

    private

    def validate_ruby_llm_available!
      return if defined?(RubyLLM)

      raise RubyLLMNotAvailableError,
        "RubyLLM is not available. Please ensure the ruby_llm gem is installed and configured."
    end

    def validate_agent_class!
      unless agent_class.respond_to?(:model) && agent_class.respond_to?(:system_prompt)
        raise ArgumentError,
          "Agent class must respond to :model and :system_prompt. Got: #{agent_class.name}"
      end
    end

    def build_chat
      RubyLLM.chat(model: agent_class.model)
    end

    def configure_chat(chat)
      # Apply system prompt
      chat.with_instructions(agent_class.system_prompt)

      # Apply schema for structured output if agent defines one
      if agent_class.respond_to?(:schema) && agent_class.schema
        chat.with_schema(agent_class.schema)
      end

      # Apply model parameters (temperature, max_tokens, etc.)
      if agent_class.respond_to?(:model_parameters)
        params = agent_class.model_parameters
        chat.with_params(**params) if params.any?
      end

      chat
    end

    def instrument_chat(chat)
      return unless observability_session

      instrumenter = Observ::ChatInstrumenter.new(
        observability_session,
        chat,
        context: default_context.merge(@context)
      )
      instrumenter.instrument!
    end

    def default_context
      {
        service: "agent_executor",
        agent_class: agent_class
      }
    end

    # Build the user prompt from input
    #
    # If the agent implements build_user_prompt, use it with the input as context.
    # Otherwise, extract text from the input directly.
    def build_user_prompt(input)
      if agent_class.respond_to?(:build_user_prompt)
        context = input.is_a?(Hash) ? input : { text: input }
        agent_class.build_user_prompt(context)
      else
        extract_text_input(input)
      end
    end

    def extract_text_input(input)
      case input
      when String
        input
      when Hash
        # Try common keys for text content
        input[:text] || input["text"] ||
          input[:content] || input["content"] ||
          input[:input] || input["input"] ||
          input.to_json
      else
        input.to_s
      end
    end

    def normalize_response(content)
      case content
      when Hash
        # Symbolize keys for consistent access
        deep_symbolize_keys(content)
      when String
        content
      else
        content.respond_to?(:to_h) ? deep_symbolize_keys(content.to_h) : content
      end
    end

    def deep_symbolize_keys(hash)
      hash.each_with_object({}) do |(key, value), result|
        new_key = key.respond_to?(:to_sym) ? key.to_sym : key
        new_value = value.is_a?(Hash) ? deep_symbolize_keys(value) : value
        result[new_key] = new_value
      end
    end
  end
end
