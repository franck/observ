# frozen_string_literal: true

module Observ
  class PromptConfigValidator
    attr_reader :config, :errors

    def initialize(config)
      @config = config
      @errors = []
    end

    def valid?
      @errors = []

      return true if config.blank?

      unless config.is_a?(Hash)
        @errors << "Config must be a Hash"
        return false
      end

      validate_against_schema
      @errors.empty?
    end

    private

    def validate_against_schema
      schema.each do |key, rules|
        value, raw_key = value_with_key(key)

        # Check required fields
        if rules[:required] && value.nil?
          @errors << "#{key} is required"
          next
        end

        # Skip validation if value is nil and not required
        next if value.nil?

        # Coerce values like numeric strings before validation
        coerced_value = coerce_value(value, rules[:type])
        assign_value(raw_key, coerced_value) if raw_key && coerced_value != value
        value = coerced_value

        # Validate type
        validate_type(key, value, rules)

        # Validate range if specified
        validate_range(key, value, rules) if rules[:range]

        # Validate allowed values if specified
        validate_allowed_values(key, value, rules) if rules[:allowed]

        # Validate array items if specified
        validate_array_items(key, value, rules) if rules[:item_type]
      end

      # Check for unknown keys
      validate_unknown_keys if schema_strict?
    end

    def validate_type(key, value, rules)
      expected_type = rules[:type]

      case expected_type
      when :integer
        unless value.is_a?(Integer)
          @errors << "#{key} must be an integer"
        end
      when :float
        unless value.is_a?(Numeric)
          @errors << "#{key} must be a number"
        end
      when :string
        unless value.is_a?(String)
          @errors << "#{key} must be a string"
        end
      when :boolean
        unless [true, false].include?(value)
          @errors << "#{key} must be a boolean"
        end
      when :array
        unless value.is_a?(Array)
          @errors << "#{key} must be an array"
        end
      when :hash
        unless value.is_a?(Hash)
          @errors << "#{key} must be a hash"
        end
      end
    end

    def validate_range(key, value, rules)
      range = rules[:range]

      return unless value.is_a?(Numeric)

      unless range.cover?(value)
        @errors << "#{key} must be between #{range.min} and #{range.max}"
      end
    end

    def validate_allowed_values(key, value, rules)
      allowed = rules[:allowed]

      unless allowed.include?(value)
        @errors << "#{key} must be one of: #{allowed.join(', ')}"
      end
    end

    def validate_array_items(key, value, rules)
      return unless value.is_a?(Array)

      item_type = rules[:item_type]

      value.each_with_index do |item, index|
        case item_type
        when :string
          unless item.is_a?(String)
            @errors << "#{key}[#{index}] must be a string"
          end
        when :integer
          unless item.is_a?(Integer)
            @errors << "#{key}[#{index}] must be an integer"
          end
        when :float
          unless item.is_a?(Numeric)
            @errors << "#{key}[#{index}] must be a number"
          end
        end
      end
    end

    def validate_unknown_keys
      schema_keys = schema.keys.map { |k| [k.to_s, k.to_sym] }.flatten
      config_keys = config.keys

      unknown_keys = config_keys - schema_keys

      if unknown_keys.any?
        @errors << "Unknown configuration keys: #{unknown_keys.join(', ')}"
      end
    end

    def schema
      @schema ||= Observ.config.prompt_config_schema
    end

    def schema_strict?
      Observ.config.prompt_config_schema_strict
    end

    def value_with_key(key)
      if config.key?(key.to_s)
        [config[key.to_s], key.to_s]
      elsif config.key?(key.to_sym)
        [config[key.to_sym], key.to_sym]
      else
        [nil, nil]
      end
    end

    def assign_value(raw_key, value)
      return unless raw_key
      config[raw_key] = value
    end

    def coerce_value(value, expected_type)
      case expected_type
      when :integer
        return value.to_i if integer_string?(value)
      when :float
        return value.to_f if numeric_string?(value)
      end
      value
    end

    def integer_string?(value)
      value.is_a?(String) && value.match?(/\A-?\d+\z/)
    end

    def numeric_string?(value)
      value.is_a?(String) && value.match?(/\A-?\d+(?:\.\d+)?\z/)
    end
  end
end
