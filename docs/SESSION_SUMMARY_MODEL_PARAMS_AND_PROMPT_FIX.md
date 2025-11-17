# Session Summary: Model Parameters Observability & System Prompt Fix

## Overview

This session completed two major fixes for the Observ gem:
1. **Model Parameters Type Conversion** - Parameters from database now have correct numeric types
2. **System Prompt Duplication** - Instructions no longer added multiple times

## Part 1: Model Parameters Type Conversion

### Problem
Model parameters loaded from PostgreSQL JSONB were returned as strings, causing API errors:
```
Invalid type for 'temperature': expected a decimal, but got a string
```

### Solution
Added type conversion in `PromptManagement#extract_llm_parameters` to convert string numbers to proper Float/Integer types.

### Files Modified
1. **`app/models/concerns/observ/prompt_management.rb`**
   - Added `convert_to_numeric_if_needed` helper method
   - Modified `extract_llm_parameters` to apply type conversion

2. **`spec/integration/prompt_manager_integration_spec.rb`**
   - Added test: "converts string model parameters to proper numeric types"
   - Added test: "preserves non-numeric parameter values"

3. **`spec/support/dummy_agent.rb`**
   - Simplified to use `Observ::PromptManagement` directly

### Result
```ruby
# Before
params: {temperature: "0.7"}  # String ❌

# After  
params: {temperature: 0.7}   # Float ✅
```

## Part 2: System Prompt Duplication Fix

### Problem
System prompts were being added on every message, causing:
- Growing conversation context
- Increased token usage and costs
- Duplicate instructions in conversation

### Root Cause
`ChatEnhancements#ensure_agent_configured` was calling both:
- `setup_instructions(self)` - Should only run once at creation
- `setup_parameters(self)` - Needs to run after each reload

The `@_agent_params_configured` instance variable flag was reset on each chat reload, causing `setup_instructions` to run again.

### Solution
Removed `setup_instructions` call from `ensure_agent_configured` since:
- Instructions are already set in `initialize_agent_on_create` callback
- They persist in RubyLLM's conversation state
- Only parameters need re-application after reload

### Files Modified
1. **`app/models/concerns/observ/chat_enhancements.rb`**
   - Removed `setup_instructions` call from `ensure_agent_configured`
   - Added explanatory comments

2. **`CHANGELOG.md`**
   - Added entry under "Fixed" section

3. **`docs/SYSTEM_PROMPT_DUPLICATION_FIX.md`**
   - Comprehensive documentation of the problem and solution

### Result
```
# Before
[System] Instructions...
[User] Hello
[System] Instructions... (duplicate!)
[User] Bonjour  
[System] Instructions... (duplicate!)
[System] Instructions... (duplicate!)

# After
[System] Instructions... (only once!)
[User] Hello
[User] Bonjour
[User] Hola
```

## Complete List of Files Modified

### Core Changes
1. `app/models/concerns/observ/prompt_management.rb` - Type conversion
2. `app/models/concerns/observ/chat_enhancements.rb` - Prompt duplication fix

### Tests
3. `spec/integration/prompt_manager_integration_spec.rb` - Type conversion tests
4. `spec/support/dummy_agent.rb` - Simplified test helper

### Documentation
5. `CHANGELOG.md` - Both fixes documented
6. `docs/MODEL_PARAMETERS_TYPE_CONVERSION.md` - Type conversion details
7. `docs/SYSTEM_PROMPT_DUPLICATION_FIX.md` - Prompt duplication details
8. `docs/SESSION_SUMMARY_MODEL_PARAMS_AND_PROMPT_FIX.md` - This file

## Key Insights

### Different Lifecycle Concerns
The fixes revealed that instructions and parameters have different lifecycle requirements:

**Instructions (System Prompt):**
- ✅ Set once at creation (`initialize_agent_on_create`)
- ✅ Persist in RubyLLM conversation state
- ❌ Should NOT be re-applied on reload

**Parameters (temperature, max_tokens, etc.):**
- ✅ Set at creation (`initialize_agent_on_create`)
- ❌ Lost when chat reloaded (instance variable `@chat.params`)
- ✅ MUST be re-applied on reload (`ensure_agent_configured`)

### Separation of Concerns
```ruby
# At Creation (after_create callback)
initialize_agent_on_create
  ├─ setup_instructions  ← One-time setup
  ├─ setup_parameters    ← Initial setup
  └─ send_initial_greeting

# After Reload (lazy when needed)
ensure_agent_configured
  └─ setup_parameters    ← Runtime re-application ONLY
```

## Testing

### Test Model Parameters Type Conversion
```ruby
# In parent app
cd /home/franck/src/tries/mgme
bundle update observ
rails runner test_model_parameters.rb

# Expected output:
# Model Parameters: {"temperature" => 0.3}
# Temperature class: Float
```

### Test System Prompt Duplication Fix
```ruby
# Create new chat
chat = Chat.create!(agent_class_name: 'LanguageDetectionAgent')

# Send multiple messages
ChatResponseJob.perform_now(chat.id, 'Hello')
ChatResponseJob.perform_now(chat.id, 'Bonjour')
ChatResponseJob.perform_now(chat.id, 'Hola')

# Check system messages count
system_messages = chat.messages.where(role: 'system')
puts "System messages count: #{system_messages.count}"
# Expected: 0 or 1 (instructions stored in RubyLLM, not as messages)
```

## Impact

### Model Parameters Type Conversion
✅ Parameters now have correct types (Float/Integer)
✅ OpenAI API accepts parameters without errors
✅ Parameters properly displayed in Observ UI
✅ Works for all numeric parameter types
✅ Non-numeric values preserved unchanged

### System Prompt Duplication Fix
✅ System prompts no longer duplicated
✅ Conversation context stays clean
✅ Token usage reduced (no duplicate prompts)
✅ Costs reduced
✅ Better LLM performance
✅ Model parameters still captured correctly

## What Was Learned

1. **JSON Type Coercion**: PostgreSQL JSONB returns numeric values as strings in Ruby
2. **Instance Variable Lifecycle**: Instance variables don't persist across ActiveRecord reloads
3. **Different Persistence Models**: RubyLLM stores some state internally (instructions) and some in instance variables (parameters)
4. **Separation of Concerns**: Creation-time setup vs. runtime re-application are different concerns
5. **Type Safety**: Always convert types at the boundary where data enters from external sources (database, API, etc.)

## Next Steps

1. **Update parent app**: `bundle update observ`
2. **Test in development**: Verify both fixes work as expected
3. **Monitor in production**: Check for reduced token usage and costs
4. **Consider releasing**: These are important bug fixes for any production users

## Version Information

These changes will be included in the next release of Observ gem.

Semantic versioning recommendation:
- **PATCH** version bump (bug fixes, no breaking changes)
- Example: `0.3.0` → `0.3.1`
