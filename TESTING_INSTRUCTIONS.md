# Testing Model Parameters Fix

## Summary of Fix

We fixed the issue where `model_parameters` was always empty `{}` in observations. The problem had TWO parts:

### Part 1: Incorrect Parameter Extraction (Fixed)
**Problem**: `extract_model_parameters` was trying to access `chat_instance.params` directly on the ActiveRecord model, but RubyLLM stores the chat in `@chat` instance variable.

**Solution**: Extract from internal RubyLLM::Chat object:
```ruby
llm_chat = chat_instance.instance_variable_get(:@chat)
params = llm_chat.params
```

### Part 2: Parameters Not Set on Chat Load (Fixed)
**Problem**: `setup_parameters` only ran on `after_create`, not on `after_find`. When `ChatResponseJob` loaded the chat with `Chat.find(id)`, RubyLLM recreated the `@chat` object WITHOUT calling `setup_parameters`, resulting in empty params.

**Solution**: Added `after_find` callback to reinitialize agent configuration when loaded from database:
```ruby
after_create :initialize_agent_on_create  # Sets params + sends greeting
after_find :initialize_agent_on_find      # Sets params (no greeting)
```

## Testing in Parent App

### Step 1: Restart Console
Since you're using a path gem, you need to reload:
```bash
# Exit Rails console and restart, OR:
reload!
```

### Step 2: Test the Complete Flow
```ruby
# 1. Create a fresh chat
test_chat = Chat.create!(agent_class_name: "LanguageDetectionAgent")

# 2. Verify params are set immediately after creation
llm_chat = test_chat.instance_variable_get(:@chat)
puts "After create: #{llm_chat.params.inspect}"
# Expected: {temperature: "0.3"}

# 3. Reload chat from database (simulates ChatResponseJob)
reloaded_chat = Chat.find(test_chat.id)

# 4. Verify params are STILL set after reload
llm_chat_reloaded = reloaded_chat.instance_variable_get(:@chat)
puts "After find: #{llm_chat_reloaded.params.inspect}"
# Expected: {temperature: "0.3"}  ← This should NOW work!

# 5. Send a message
ChatResponseJob.perform_now(reloaded_chat.id, "Bonjour comment ça va?")

# 6. Check the observation
generation = Observ::Generation.order(created_at: :desc).first
puts "\n=== VERIFICATION ==="
puts "model_parameters: #{generation.model_parameters.inspect}"
# Expected: {"temperature" => "0.3"}  ← Should NOW be populated!

puts "model: #{generation.model}"
puts "cost: #{generation.cost_usd}"
puts "tokens: #{generation.usage['total_tokens']}"

# 7. View in UI
puts "\nView in browser:"
puts "http://localhost:3000/observ/observations/#{generation.id}"
```

### Expected Results

#### Before Fix:
```ruby
generation.model_parameters
=> {}  # ❌ EMPTY
```

#### After Fix:
```ruby
generation.model_parameters
=> {"temperature" => "0.3"}  # ✅ POPULATED!
```

### Step 3: Verify in UI

1. Go to `/observ/observations`
2. Click on the latest Generation observation
3. You should now see a section:

```
┌─────────────────────────────────┐
│ Model Parameters                │
├─────────────────────────────────┤
│ Temperature:  0.3               │
└─────────────────────────────────┘
```

## Verification Checklist

- [ ] `after_create` callback sets params (check console output)
- [ ] `after_find` callback sets params (check console output)
- [ ] `ChatInstrumenter` extracts params from `@chat` object
- [ ] `model_parameters` column in database is populated
- [ ] Model Parameters section appears in Observ UI
- [ ] Parameters match what's defined in `agent.model_parameters`

## Rollback (if needed)

If something goes wrong:
```ruby
# Check what callbacks are registered
Chat._create_callbacks.map(&:filter)
# Should include: :initialize_agent_on_create

Chat._find_callbacks.map(&:filter)
# Should include: :ensure_instrumented_if_needed, :initialize_agent_on_find
```

## Common Issues

### Issue: Params still empty after fix
**Check**: Did you reload the console?
```ruby
reload!
```

### Issue: Old observations still show empty params
**Expected**: Old observations created before the fix will always have empty params. Only NEW observations (created after the fix) will have populated params.

### Issue: Greeting message sent multiple times
**Check**: Make sure `send_initial_greeting` is ONLY in `initialize_agent_on_create`, NOT in `initialize_agent_on_find`.

## Success Criteria

✅ **The fix is working if:**
1. `llm_chat.params` shows `{temperature: "0.3"}` after BOTH `create` and `find`
2. `generation.model_parameters` shows `{"temperature" => "0.3"}` in database
3. Model Parameters section is visible in Observ UI at `/observ/observations/:id`
4. The temperature value matches what's defined in the agent's `model_parameters` method

## Fix History

### V2: Added Recursion Guard (Current)
**Issue**: The `after_find` callback was being triggered repeatedly when loading associated records (messages, etc.), causing infinite recursion.

**Solution**: Added `@_agent_initialized_on_find` flag to ensure initialization only happens once per instance.

```ruby
def initialize_agent_on_find
  return if @_agent_initialized_on_find  # Guard against recursion
  # ... setup code ...
  @_agent_initialized_on_find = true
end
```

This prevents the stack overflow error while still ensuring params are set when the chat is loaded.
