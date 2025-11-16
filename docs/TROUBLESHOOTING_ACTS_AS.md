# Troubleshooting: acts_as_model and acts_as_tool_call

## Problem

You see one of these errors:

```
undefined local variable or method 'acts_as_model' for class Model
undefined local variable or method 'acts_as_tool_call' for class ToolCall
NoMethodError: undefined method 'save_to_database' for class Model
```

## Root Cause

`acts_as_model` and `acts_as_tool_call` **ARE valid RubyLLM macros**, but they weren't loaded yet when your models tried to use them.

## Solution

The models SHOULD use `acts_as_model` and `acts_as_tool_call`. The issue is the load order.

### Fix: Ensure RubyLLM is Required

Make sure your `config/initializers/ruby_llm.rb` is loaded and RubyLLM is properly configured:

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.default_model = 'gpt-4o-mini'
  
  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
  
  # Optional: Increase timeout
  # config.request_timeout = 600
end
```

### Correct Model Definitions

**app/models/model.rb:**
```ruby
class Model < ApplicationRecord
  acts_as_model
end
```

**app/models/tool_call.rb:**
```ruby
class ToolCall < ApplicationRecord
  acts_as_tool_call
end
```

**app/models/chat.rb:**
```ruby
class Chat < ApplicationRecord
  include Observ::ObservabilityInstrumentation
  
  acts_as_chat
  
  # ... your agent code
end
```

**app/models/message.rb:**
```ruby
class Message < ApplicationRecord
  include Observ::TraceAssociation
  
  acts_as_message
  
  # ... your code
end
```

## All Four acts_as Macros

RubyLLM provides these macros:

1. ✅ `acts_as_chat` - For Chat model
2. ✅ `acts_as_message` - For Message model
3. ✅ `acts_as_model` - For Model model (tracks LLM models)
4. ✅ `acts_as_tool_call` - For ToolCall model (tracks tool usage)

All four are valid and should be used!

## If Still Having Issues

1. **Check Gemfile has ruby_llm:**
   ```ruby
   gem 'ruby_llm'
   ```

2. **Bundle install:**
   ```bash
   bundle install
   ```

3. **Check RubyLLM version:**
   ```bash
   bundle show ruby_llm
   ```

4. **Clear Spring cache:**
   ```bash
   bin/spring stop
   ```

5. **Restart server:**
   ```bash
   bin/dev
   ```

## Load Order Issue

If you're still getting errors, it might be a load order issue. Try explicitly requiring RubyLLM in your model:

```ruby
# app/models/model.rb
require 'ruby_llm'

class Model < ApplicationRecord
  acts_as_model
end
```

But this shouldn't be necessary if your initializer is correct.
