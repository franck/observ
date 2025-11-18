# Task 1: Validate Prompt Configuration Format

## Overview
Implement validation for prompt configuration format to ensure data integrity and prevent runtime errors from malformed configurations.

## Current State
- Prompt model has a `config` field (JSONB column in database)
- Basic normalization exists in `normalize_config` callback (app/models/observ/prompt.rb:248-262)
- Config is converted from String to Hash and defaults to empty hash on parse errors
- No validation of config structure or required fields

## Problem Statement
Currently, the prompt configuration:
1. Can be any arbitrary JSON structure
2. Has no schema validation
3. May contain invalid or unexpected keys
4. Could cause runtime errors when used by agents

## Proposed Solution

### Phase 1: Define Configuration Schema
Create a schema definition that specifies:
- Valid configuration keys
- Expected data types for each key
- Required vs. optional fields
- Default values
- Allowed value ranges/options

Example schema:
```ruby
{
  temperature: { type: :float, required: false, range: 0.0..2.0, default: 0.7 },
  max_tokens: { type: :integer, required: false, range: 1..100000 },
  top_p: { type: :float, required: false, range: 0.0..1.0 },
  frequency_penalty: { type: :float, required: false, range: -2.0..2.0 },
  presence_penalty: { type: :float, required: false, range: -2.0..2.0 },
  stop_sequences: { type: :array, required: false, item_type: :string }
}
```

### Phase 2: Implement Validator
Create `Observ::PromptConfigValidator` service class:
- Location: `app/validators/observ/prompt_config_validator.rb`
- Validates config against schema
- Returns detailed error messages
- Supports custom validation rules

### Phase 3: Integrate with Model
Add custom validation to Prompt model:
```ruby
validate :validate_config_format

def validate_config_format
  return if config.blank?
  
  validator = Observ::PromptConfigValidator.new(config)
  unless validator.valid?
    validator.errors.each do |error|
      errors.add(:config, error)
    end
  end
end
```

### Phase 4: Testing
- Unit tests for validator with valid/invalid configs
- Model tests for validation integration
- Integration tests for prompt creation/update with various configs

## Files to Modify
- `app/models/observ/prompt.rb` - Add validation
- `app/validators/observ/prompt_config_validator.rb` - New validator class
- `lib/observ/configuration.rb` - Add schema configuration option
- `spec/validators/observ/prompt_config_validator_spec.rb` - New tests
- `spec/models/observ/prompt_spec.rb` - Add validation tests

## Benefits
1. Data integrity - ensure configs are valid before saving
2. Better error messages - clear feedback on what's wrong
3. Documentation - schema serves as config reference
4. Safety - prevent runtime errors from invalid configs
5. Flexibility - schema can be customized per installation

## Considerations
- Backward compatibility - existing prompts with arbitrary configs
- Migration path for invalid existing data
- Performance impact of validation on save
- Should schema be configurable or hardcoded?
