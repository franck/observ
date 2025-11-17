# Chat & Agent Testing Installation Guide

This guide walks you through installing the Observ chat/agent testing feature, which provides a UI for testing LLM agents with full observability.

## Prerequisites

- Rails 7.0+ application
- Observ gem installed (core features)
- RubyLLM gem and infrastructure installed (see below)

## What You Get

The chat feature adds **Observ-specific enhancements** on top of RubyLLM's chat infrastructure:

- **Chat UI** at `/observ/chats` for interactive agent testing
- **Agent Management** - Create and select different agents
- **Message Streaming** - Real-time responses
- **Tool Call Visualization** - See tools being used
- **Full Observability** - All interactions tracked in sessions/traces
- **Agent Infrastructure** - BaseAgent, AgentProvider, and concerns
- **Example Agent** - SimpleAgent to get started

## Installation Steps

### 1. Install RubyLLM Infrastructure

First, ensure RubyLLM gem is installed. Add to your `Gemfile`:

```ruby
gem 'ruby_llm'
```

Then run:

```bash
bundle install
```

### 2. Run RubyLLM Install Generator

This creates the core chat infrastructure (Chat, Message, ToolCall, Model):

```bash
rails generate ruby_llm:install
```

### 3. Run Migrations

```bash
rails db:migrate
```

### 4. Load Model Registry

This populates the models table with available LLM models:

```bash
rails ruby_llm:load_models
```

### 5. Configure RubyLLM

The install generator creates `config/initializers/ruby_llm.rb`. Update it with your API keys:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  
  # Use the new association-based acts_as API (automatically set by generator)
  config.use_new_acts_as = true
  
  # Optional: Configure other providers
  # config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  # config.google_api_key = ENV['GOOGLE_API_KEY']
end
```

### 6. Install Observ Core (if not already done)

```bash
rails generate observ:install
rails db:migrate
```

### 7. Install Observ Chat Feature

Now install the Observ chat enhancements:

```bash
rails generate observ:install:chat
```

This will:
- Add **1 migration** (agent_class_name to chats table)
- Enhance **Chat and Message models** with Observ concerns
- Create **Agent infrastructure** (BaseAgent, AgentProvider, concerns)
- Create **Example agent** (SimpleAgent)
- Create **ChatResponseJob** for async message processing
- Create **ThinkTool** (basic example)

### 8. Run the Migration

```bash
rails db:migrate
```

### 9. Set Environment Variables

Add to `.env` or your environment:

```bash
OPENAI_API_KEY=your_openai_api_key_here
```

### 10. Configure Observability (if not done)

Create `config/initializers/observability.rb`:

```ruby
Rails.application.config.observability = ActiveSupport::OrderedOptions.new

# Enable/disable observability
Rails.application.config.observability.enabled = 
  ENV.fetch("OBSERVABILITY_ENABLED", "true") == "true"

# Auto-instrument RubyLLM chats
Rails.application.config.observability.auto_instrument_chats = 
  ENV.fetch("OBSERVABILITY_AUTO_INSTRUMENT", "true") == "true"

# Debug logging
Rails.application.config.observability.debug = 
  ENV.fetch("OBSERVABILITY_DEBUG", Rails.env.development?.to_s) == "true"
```

### 11. Start Your Server

```bash
bin/dev
# or
rails server
```

### 12. Test the Chat UI

Visit: http://localhost:3000/observ/chats

You should see:
- "New Chat" button
- Agent selection dropdown (with SimpleAgent)
- Chat list (initially empty)

## Quick Reference: Installation Order

For a **fresh Rails app**, run these commands in order:

```bash
# 1. Add gems to Gemfile
# gem 'ruby_llm'
# gem 'observ'

# 2. Install dependencies
bundle install

# 3. Install RubyLLM infrastructure
rails generate ruby_llm:install
rails db:migrate
rails ruby_llm:load_models

# 4. Install Observ core
rails generate observ:install
rails db:migrate

# 5. Install Observ chat feature
rails generate observ:install:chat
rails db:migrate

# 6. Start server
rails server
```

## Generator Options

### Skip Tools

If you don't want the example tool:

```bash
rails generate observ:install:chat --skip-tools
```

### Skip Migrations

If you already have the agent_class_name field:

```bash
rails generate observ:install:chat --skip-migrations
```

### Skip Job

If you have a custom job implementation:

```bash
rails generate observ:install:chat --skip-job
```

## File Structure After Installation

```
app/
├── models/
│   ├── chat.rb                    # RubyLLM chat model (enhanced by Observ)
│   ├── message.rb                 # RubyLLM message model (enhanced by Observ)
│   ├── tool_call.rb               # RubyLLM tool call model
│   └── model.rb                   # RubyLLM model registry
├── agents/                        # Added by observ:install:chat
│   ├── base_agent.rb              # Base agent class
│   ├── simple_agent.rb            # Example agent
│   ├── agent_provider.rb          # Agent discovery
│   └── concerns/
│       ├── agent_selectable.rb    # UI selection
│       └── prompt_management.rb   # Prompt management
├── jobs/                          # Added by observ:install:chat
│   └── chat_response_job.rb       # Async message processing
└── tools/                         # Added by observ:install:chat
    └── think_tool.rb              # Basic tool example

db/migrate/
# From ruby_llm:install
├── XXXXXX_create_chats.rb
├── XXXXXX_create_messages.rb
├── XXXXXX_create_tool_calls.rb
├── XXXXXX_create_models.rb
├── XXXXXX_add_references_to_chats_tool_calls_and_messages.rb
# From observ:install:chat
└── XXXXXX_add_agent_class_name_to_chats.rb

config/initializers/
├── ruby_llm.rb                    # RubyLLM configuration
└── observability.rb               # Observ configuration
```

## Creating Your First Custom Agent

1. Create a new file in `app/agents/`:

```ruby
# app/agents/my_agent.rb
class MyAgent < BaseAgent
  include AgentSelectable

  def self.display_name
    "My Custom Agent"
  end

  def self.description
    "Describe what your agent does"
  end

  def self.system_prompt
    "You are a helpful assistant that..."
  end

  def self.default_model
    "gpt-4o-mini"
  end

  def self.initial_greeting
    "Hello! I'm your custom agent."
  end

  # Optional: Add tools
  # def self.tools
  #   [MyCustomTool]
  # end
end
```

2. Restart your server

3. Visit `/observ/chats` - your agent should appear in the dropdown!

## Using Prompt Management

To use database-managed prompts instead of hardcoded ones:

```ruby
class MyAgent < BaseAgent
  include AgentSelectable
  include PromptManagement  # Add this!

  FALLBACK_PROMPT = "You are a helpful assistant."

  use_prompt_management(
    prompt_name: "my-agent-system-prompt",
    fallback: FALLBACK_PROMPT
  )

  def self.display_name
    "My Agent"
  end

  def self.default_model
    "gpt-4o-mini"
  end

  # system_prompt is now managed by PromptManagement
  # It will fetch from the database or use fallback
end
```

Then create the prompt in Observ UI:
- Visit `/observ/prompts`
- Create new prompt named "my-agent-system-prompt"
- Set state to "production"
- Agent will automatically use it!

## Creating Custom Tools

1. Create a tool class:

```ruby
# app/tools/my_tool.rb
require "ruby_llm"

class MyTool < RubyLLM::Tool
  description "What this tool does"

  param :input,
        desc: "Description of the parameter",
        type: :string

  attr_accessor :observability

  def initialize(observability = nil)
    @observability = observability
  end

  def execute(input:)
    # Your tool logic here
    result = do_something(input)
    
    "Tool result: #{result}"
  end

  private

  def do_something(input)
    # Implementation
  end
end
```

2. Add to your agent:

```ruby
class MyAgent < BaseAgent
  # ...
  
  def self.tools
    [MyTool, ThinkTool]
  end
end
```

## Troubleshooting

### Chat routes return 404

**Problem:** `/observ/chats` returns 404

**Solution:** The routes are conditionally mounted. Check:

```bash
bin/rails console
> defined?(::Chat)
> ::Chat.respond_to?(:acts_as_chat)
```

Both should return truthy values. If not:
- Ensure you ran `rails generate ruby_llm:install` first
- Ensure migrations ran: `rails db:migrate`
- Ensure Chat model exists in `app/models/chat.rb`
- Ensure RubyLLM is in Gemfile: `gem 'ruby_llm'`
- Restart server

### Generator fails with "RubyLLM models not found"

**Problem:** `rails generate observ:install:chat` fails with an error about missing models

**Solution:** You need to install RubyLLM infrastructure first:

```bash
# Install RubyLLM
rails generate ruby_llm:install
rails db:migrate
rails ruby_llm:load_models

# Then install Observ chat
rails generate observ:install:chat
```

### Agent doesn't appear in dropdown

**Problem:** Created an agent but it doesn't show in UI

**Checklist:**
- [ ] Agent extends `BaseAgent`
- [ ] Agent includes `AgentSelectable`
- [ ] Agent implements `display_name` method
- [ ] File is in `app/agents/` directory
- [ ] Server restarted after creating agent

### Messages not streaming

**Problem:** Messages appear all at once instead of streaming

**Solution:** Ensure you have Turbo configured:

```ruby
# Gemfile
gem "turbo-rails"
```

```javascript
// app/javascript/application.js
import "@hotwired/turbo-rails"
```

### Tool calls failing

**Problem:** Agent tries to call tool but gets error

**Checklist:**
- [ ] Tool extends `RubyLLM::Tool`
- [ ] Tool has `description` and `param` definitions
- [ ] Tool implements `execute` method with named parameters
- [ ] Tool is added to agent's `tools` array
- [ ] Tool file is in `app/tools/` directory

### Observability not tracking

**Problem:** Chats work but don't appear in `/observ/sessions`

**Solution:** Check observability configuration:

```bash
bin/rails console
> Rails.configuration.observability.enabled
> Chat.first.observ_session  # Should return a session
```

If `nil`, check:
- `config/initializers/observability.rb` exists
- `observability.enabled = true`
- `observability.auto_instrument_chats = true`
- Restart server

### Missing partial messages/_content

**Problem:** `ActionView::MissingTemplate` error for `messages/_content`

**Solution:** This partial is required for message streaming. If the generator didn't create it, manually create:

```erb
<!-- app/views/messages/_content.html.erb -->
<%= content %>
```

Or re-run the generator to create missing files:
```bash
rails generate observ:install:chat
```

### NoMethodError: undefined method 'observability'

**Problem:** `ChatResponseJob` fails with error about `Rails.configuration.observability`

**Solution:** The generator should create `config/initializers/observability.rb` automatically. If it's missing:

```ruby
# config/initializers/observability.rb
Rails.application.configure do
  config.observability = ActiveSupport::OrderedOptions.new
  config.observability.debug = Rails.env.development?
end
```

Or re-run the generator:
```bash
rails generate observ:install:chat
```

Note: The job works fine without this configuration - it only controls whether metrics are logged. Set `config.observability.debug = false` to disable debug logging.

## Advanced Topics

### Custom Message Broadcasting

Customize how messages are broadcast:

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  # ...
  
  def broadcast_append_chunk(content)
    # Custom broadcasting logic
    broadcast_append_to "chat_#{chat_id}",
      target: "message_#{id}_content",
      partial: "messages/custom_content",
      locals: { content: content, message: self }
  end
end
```

### Agent Categories

Group agents in the UI:

```ruby
class MyAgent < BaseAgent
  include AgentSelectable

  def self.category
    "Research"  # Agents grouped by category
  end
end
```

### Dynamic System Prompts

Use prompt variables for dynamic content:

```ruby
class MyAgent < BaseAgent
  include PromptManagement

  def self.prompt_variables
    super.merge(
      user_name: "Alice",
      custom_data: fetch_some_data
    )
  end
end
```

Then in your prompt template:
```
Hello {{user_name}}! Today is {{current_date}}.
Custom data: {{custom_data}}
```

## Next Steps

- Read [Agent Development Guide](AGENT_DEVELOPMENT.md)
- Read [Tool Development Guide](TOOL_DEVELOPMENT.md)
- Explore [Prompt Management](../README.md#prompt-management)
- Check [Observability Features](../README.md#features)

## Getting Help

- Check the [main README](../README.md)
- Review example agents in `app/agents/`
- Look at RubyLLM documentation: https://github.com/alexrudall/ruby_llm
- File an issue: https://github.com/yourusername/observ/issues
