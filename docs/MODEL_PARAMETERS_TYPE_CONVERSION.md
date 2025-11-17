# Model Parameters Type Conversion Fix

## Problem

Model parameters (temperature, max_tokens, etc.) were being stored as **strings** instead of numeric types when loaded from the database, causing API errors:

```ruby
# ❌ BEFORE - Parameters as strings
params: {temperature: "0.7"}  # String, not Float

# OpenAI API Error:
# Invalid type for 'temperature': expected a decimal, but got a string instead.
```

## Root Cause

The parameters are stored in the `Observ::Prompt` model's `config` field as JSON. When Rails reads JSON from PostgreSQL's `jsonb` column, numeric values become **strings**:

```ruby
# In database (PostgreSQL JSONB):
config: {"temperature": 0.7, "max_tokens": 2000}

# After loading from database:
prompt.config  # => {"temperature" => "0.7", "max_tokens" => "2000"}
                # All values are strings! ⚠️
```

The `PromptManagement` concern's `extract_llm_parameters` method was extracting these values but not converting them back to proper numeric types.

## Solution

Added type conversion in `PromptManagement#extract_llm_parameters` to convert string numbers back to their proper types:

### File: `app/models/concerns/observ/prompt_management.rb`

```ruby
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
```

## How It Works

1. **Extract parameters** from the prompt config (as before)
2. **Transform each value**:
   - If it's a **float string** like `"0.7"` → convert to `0.7` (Float)
   - If it's an **integer string** like `"2000"` → convert to `2000` (Integer)
   - If it's **not a numeric string** → leave as-is (e.g., arrays, hashes, other strings)

## Results

```ruby
# ✅ AFTER - Parameters with correct types
params: {
  temperature: 0.7,        # Float
  max_tokens: 2000,        # Integer
  top_p: 0.9,             # Float
  frequency_penalty: 0.5,  # Float
  presence_penalty: 0.3    # Float
}

# API calls succeed! ✓
```

## Testing

Added comprehensive tests in `spec/integration/prompt_manager_integration_spec.rb`:

```ruby
it "converts string model parameters to proper numeric types" do
  create(:observ_prompt,
    :production,
    name: "test-agent-prompt",
    config: {
      "temperature" => "0.7",      # String from JSON
      "max_tokens" => "2000",      # String from JSON
      "top_p" => "0.9"            # String from JSON
    }
  )

  params = agent_class.model_parameters

  # Verify conversion
  expect(params[:temperature]).to eq(0.7)
  expect(params[:temperature]).to be_a(Float)
  
  expect(params[:max_tokens]).to eq(2000)
  expect(params[:max_tokens]).to be_a(Integer)
end
```

## Files Modified

1. **`app/models/concerns/observ/prompt_management.rb`**
   - Added `convert_to_numeric_if_needed` helper method
   - Modified `extract_llm_parameters` to apply type conversion

2. **`spec/integration/prompt_manager_integration_spec.rb`**
   - Added test: "converts string model parameters to proper numeric types"
   - Added test: "preserves non-numeric parameter values"

3. **`spec/support/dummy_agent.rb`**
   - Simplified to use `Observ::PromptManagement` concern directly
   - Removed custom implementation (now tests actual concern code)

## Impact

- ✅ Model parameters are now captured with **correct types**
- ✅ OpenAI API (and other LLM APIs) accept the parameters without errors
- ✅ Parameters are properly displayed in the Observ UI
- ✅ Works for all numeric parameter types (temperature, max_tokens, top_p, etc.)
- ✅ Non-numeric values (arrays, hashes) are preserved unchanged

## Future Considerations

This fix is applied at the **concern level** in `PromptManagement`, which means:
- All agents using `Observ::PromptManagement` get the fix automatically
- No changes needed in individual agent classes
- The fix is centralized and consistent across all agents
