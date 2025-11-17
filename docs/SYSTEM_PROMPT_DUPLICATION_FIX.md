# System Prompt Duplication Fix

## Problem

When using agents in Observ chat, the system prompt was being added **multiple times** - once for each user message sent. This caused:

1. Growing conversation context with duplicate instructions
2. Increased token usage and costs
3. Potential confusion in LLM responses
4. Performance degradation with longer conversations

## Example of the Bug

```
# First message:
[System] You are a language detection specialist...
[User] Hello
[Assistant] English

# Second message:
[System] You are a language detection specialist...  # ← First copy
[System] You are a language detection specialist...  # ← DUPLICATE!
[User] Bonjour
[Assistant] French

# Third message:
[System] You are a language detection specialist...  # ← First copy
[System] You are a language detection specialist...  # ← Second copy
[System] You are a language detection specialist...  # ← THIRD COPY!
[User] Hola
[Assistant] Spanish
```

## Root Cause

The issue was in `ChatEnhancements#ensure_agent_configured` which was calling **both**:
- `setup_instructions(self)` - Sets system prompt
- `setup_parameters(self)` - Sets model parameters

### The Lifecycle Problem

1. **Chat Creation** (`after_create` callback):
   ```ruby
   def initialize_agent_on_create
     agent_class.setup_instructions(self)   # ✅ Instructions set - CORRECT
     agent_class.setup_parameters(self)     # ✅ Parameters set - CORRECT
     agent_class.send_initial_greeting(self)
   end
   ```

2. **User Sends Message** (ChatResponseJob):
   ```ruby
   chat = Chat.find(chat_id)  # ⚠️ New instance from database
   chat.ask(content)
   ```

3. **ChatInstrumenter Calls** `ensure_agent_configured`:
   ```ruby
   def ensure_agent_configured
     return if @_agent_params_configured  # ⚠️ Instance variable = nil on reload!
     
     agent_class.setup_instructions(self)  # ❌ ADDS INSTRUCTIONS AGAIN!
     agent_class.setup_parameters(self)    # ✅ Re-applies params - NEEDED
     @_agent_params_configured = true
   end
   ```

### Why This Happened

**Instance Variable Flag Doesn't Persist:**
- `@_agent_params_configured` is an **instance variable** (in Ruby memory)
- When chat is reloaded from database (`Chat.find`), a **new instance** is created
- The flag resets to `nil` on each reload
- `ensure_agent_configured` runs again, adding instructions **again**

**Different Persistence Characteristics:**
- **Instructions**: Persist in RubyLLM's internal conversation state
- **Parameters**: Lost when chat reloaded (stored in `@chat.params` instance variable)

Therefore:
- ✅ Parameters **NEED** to be re-applied after reload
- ❌ Instructions **SHOULD NOT** be re-applied (they're already there!)

## The Solution

Separate the concerns - instructions are a **one-time setup** (at creation), while parameters are a **runtime concern** (need re-application).

### File: `app/models/concerns/observ/chat_enhancements.rb`

**Before:**
```ruby
def ensure_agent_configured
  return unless respond_to?(:agent_class) && agent_class_name.present?
  return if @_agent_params_configured

  agent_class.setup_instructions(self)  # ❌ Adds instructions every time
  agent_class.setup_parameters(self)
  @_agent_params_configured = true
end
```

**After:**
```ruby
def ensure_agent_configured
  return unless respond_to?(:agent_class) && agent_class_name.present?
  return if @_agent_params_configured

  # Only re-apply parameters, not instructions
  # Instructions were already set at creation time
  agent_class.setup_parameters(self)
  @_agent_params_configured = true
end
```

## Why This Fix Works

1. **Instructions set once** in `initialize_agent_on_create` (after_create callback)
2. **Instructions persist** in RubyLLM's conversation context
3. **Parameters re-applied** each time via `ensure_agent_configured` (they're lost on reload)
4. **No duplication** because `setup_instructions` only called once

## Lifecycle Flow After Fix

```
Chat Created
  ↓
initialize_agent_on_create
  ├─ setup_instructions     ← Instructions set ONCE ✅
  ├─ setup_parameters       ← Parameters set
  └─ send_initial_greeting
  ↓
[System] You are a language detection specialist...
[Assistant] I can detect languages...

─────────────────────────────────

User sends message #1
  ↓
Chat.find(id)  ← NEW instance from DB
  ↓
ChatInstrumenter calls ensure_agent_configured
  ↓
setup_parameters           ← ONLY parameters re-applied ✅
  ↓
[User] Hello
[Assistant] English

─────────────────────────────────

User sends message #2
  ↓
Chat.find(id)  ← NEW instance from DB
  ↓
ChatInstrumenter calls ensure_agent_configured
  ↓
setup_parameters           ← ONLY parameters re-applied ✅
  ↓
[User] Bonjour
[Assistant] French

✅ No duplicate system prompts!
```

## Related Changes

This fix complements the model parameters observability implementation:
- Model parameters need to be re-applied after reload (lost in `@chat.params`)
- Instructions do NOT need to be re-applied (persist in conversation)
- `ensure_agent_configured` now correctly handles only the runtime concern (parameters)

## Testing

To verify the fix works:

1. **Create new chat** with any agent (e.g., LanguageDetectionAgent)
2. **Send first message**: Verify system prompt appears once
3. **Send second message**: Verify system prompt is NOT duplicated
4. **Send third message**: Verify system prompt still appears only once
5. **Check observation**: Verify model parameters are still captured correctly

### Expected Behavior

```ruby
# Check conversation messages
chat = Chat.last
messages = chat.messages.where(role: 'system')

# Should have exactly ONE system message (from initialization)
expect(messages.count).to eq(1)

# Check model parameters still work
generation = Observ::Generation.last
expect(generation.model_parameters['temperature']).to eq(0.3)
```

## Impact

✅ **Fixed:**
- System prompts no longer duplicated
- Conversation context stays clean
- Token usage reduced
- Costs reduced
- Better LLM performance

✅ **Preserved:**
- Model parameters still captured correctly
- Observations still show all metadata
- Parameters re-applied after chat reload
- All other functionality unchanged

## Files Modified

1. **`app/models/concerns/observ/chat_enhancements.rb`**
   - Removed `setup_instructions` call from `ensure_agent_configured`
   - Added explanatory comments

2. **`CHANGELOG.md`**
   - Documented fix under "Fixed" section

3. **`docs/SYSTEM_PROMPT_DUPLICATION_FIX.md`** (this file)
   - Comprehensive explanation of problem and solution
