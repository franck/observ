# frozen_string_literal: true

module Observ
  # Null Object pattern for Prompt
  # Used when a prompt is not found, providing a fallback with the same interface
  class NullPrompt
    attr_reader :name, :prompt, :config

    def initialize(name:, fallback_text:)
      @name = name
      @prompt = fallback_text
      @config = {}
    end

    # Returns nil to indicate this is not a real prompt
    def version
      nil
    end

    # Returns the fallback text as-is (no variable compilation)
    def compile(variables = {})
      @prompt
    end

    # Null prompts are always in a "fallback" state
    def state
      "fallback"
    end

    def draft?
      false
    end

    def production?
      false
    end

    def archived?
      false
    end

    def persisted?
      false
    end

    def id
      nil
    end

    # For logging/debugging
    def to_s
      "NullPrompt(#{name})"
    end

    def inspect
      "#<Observ::NullPrompt name: #{name.inspect}, fallback: #{prompt[0..50].inspect}...>"
    end
  end
end
