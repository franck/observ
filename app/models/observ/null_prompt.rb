# frozen_string_literal: true

require "mustache"

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

    # Compile prompt with Mustache templating (same as Prompt)
    def compile(variables = {})
      return @prompt if variables.empty?

      Mustache.render(@prompt, variables)
    end

    # Compile with validation (raises if missing top-level variables)
    # Note: Variables inside sections (loops) are validated at render time by Mustache
    def compile_with_validation(variables = {})
      required_vars = required_variables
      provided_keys = variables.keys.map(&:to_s)

      missing_vars = required_vars.reject do |var|
        # Handle dot notation (e.g., "user.name" - check if "user" key exists)
        root_key = var.split(".").first
        provided_keys.include?(var) || provided_keys.include?(root_key)
      end

      if missing_vars.any?
        raise Observ::VariableSubstitutionError, "Missing variables: #{missing_vars.join(', ')}"
      end

      compile(variables)
    end

    # Extract top-level variables from template (for validation purposes)
    def required_variables
      template_without_sections = strip_sections(@prompt)
      template_without_sections.scan(/\{\{([^#\^\/!>\{\s][^}\s]*)\}\}/).flatten.uniq
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

    private

    # Strip section content from template for top-level variable extraction
    # Removes content between {{#section}}...{{/section}} and {{^section}}...{{/section}}
    def strip_sections(template)
      result = template.dup

      # Match sections: {{#name}}...{{/name}} or {{^name}}...{{/name}}
      # Use non-greedy matching and handle nesting by repeating until stable
      loop do
        previous = result
        result = result.gsub(/\{\{[#\^](\w+)\}\}.*?\{\{\/\1\}\}/m, "")
        break if result == previous
      end

      result
    end
  end
end
