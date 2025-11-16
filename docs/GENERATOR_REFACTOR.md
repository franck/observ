# Generator Refactor: Removing Duplication with RubyLLM

## Overview

This document describes the refactor of the `observ:install:chat` generator to eliminate duplication with `ruby_llm:install`.

## Problem

The `observ:install:chat` generator was duplicating all functionality from `ruby_llm:install`:

- Creating the same 4 tables (chats, messages, tool_calls, models)
- Creating the same 4 model files
- Managing the same migrations
- Potential for schema conflicts and maintenance issues

## Solution

The generator has been refactored to:

1. **Depend on RubyLLM infrastructure** - Assumes `ruby_llm:install` has been run first
2. **Only add Observ-specific functionality** - Enhances existing models instead of creating new ones
3. **Check prerequisites** - Fails gracefully with helpful error messages if RubyLLM isn't installed

## Changes Made

### Generator Changes

**Before:**
```ruby
def create_migrations
  # Created 6 migrations including all RubyLLM tables
  migration_template "create_chats.rb.tt"
  migration_template "create_messages.rb.tt"
  migration_template "create_tool_calls.rb.tt"
  migration_template "create_models.rb.tt"
  migration_template "add_references.rb.tt"
  migration_template "add_agent_class_name.rb.tt"
end

def create_models
  # Created all 4 models from scratch
  template "chat.rb.tt"
  template "message.rb.tt"
  template "tool_call.rb.tt"
  template "model.rb.tt"
end
```

**After:**
```ruby
def check_prerequisites
  check_ruby_llm_gem
  check_ruby_llm_models_installed  # Verifies RubyLLM models exist
end

def create_migrations
  # Only creates Observ-specific migration
  migration_template "add_agent_class_name.rb.tt"
end

def enhance_models
  # Injects Observ concerns into existing RubyLLM models
  enhance_chat_model      # Adds Observ::ObservabilityInstrumentation
  enhance_message_model   # Adds Observ::TraceAssociation
end
```

### Files Removed

**Migrations removed** (now provided by ruby_llm:install):
- `create_chats.rb.tt`
- `create_messages.rb.tt`
- `create_tool_calls.rb.tt`
- `create_models.rb.tt`
- `add_references.rb.tt`

**Model templates removed** (now provided by ruby_llm:install):
- `chat.rb.tt`
- `message.rb.tt`
- `tool_call.rb.tt`
- `model.rb.tt`

**Migrations kept**:
- `add_agent_class_name.rb.tt` - Adds Observ-specific field to chats

### Files Created/Enhanced

The generator now **enhances** existing models by injecting:

**Chat model enhancements:**
```ruby
include Observ::ObservabilityInstrumentation

after_create :initialize_agent, if: -> { agent_class_name.present? }

def agent_class
  return BaseAgent if agent_class_name.blank?
  agent_class_name.constantize
rescue NameError
  Rails.logger.warn "Agent class #{agent_class_name} not found"
  BaseAgent
end

def setup_tools
  agent_class.setup_tools(self)
end

private

def initialize_agent
  agent_class.setup_instructions(self)
  agent_class.send_initial_greeting(self)
end
```

**Message model enhancements:**
```ruby
include Observ::TraceAssociation

def broadcast_append_chunk(content)
  broadcast_append_to "chat_#{chat_id}",
    target: "message_#{id}_content",
    partial: "messages/content",
    locals: { content: content }
end
```

## New Installation Flow

### Fresh Rails App

```bash
# 1. Add gems to Gemfile
# gem 'ruby_llm'
# gem 'observ'

# 2. Install dependencies
bundle install

# 3. Install RubyLLM infrastructure (NEW REQUIREMENT)
rails generate ruby_llm:install
rails db:migrate
rails ruby_llm:load_models

# 4. Install Observ core
rails generate observ:install
rails db:migrate

# 5. Install Observ chat feature
rails generate observ:install:chat
rails db:migrate
```

### What Each Command Does

**`rails generate ruby_llm:install`**
- Creates migrations for chats, messages, tool_calls, models tables
- Creates Chat, Message, ToolCall, Model model files
- Installs ActiveStorage for file attachments
- Creates RubyLLM initializer

**`rails ruby_llm:load_models`**
- Populates models table from bundled models.json
- Loads 500+ model definitions with capabilities and pricing

**`rails generate observ:install`**
- Creates Observ core tables (sessions, traces, observations, prompts, annotations)
- Sets up Observ routes and controllers

**`rails generate observ:install:chat`**
- Adds agent_class_name to chats table
- Enhances Chat and Message models with Observ concerns
- Creates agent infrastructure (BaseAgent, AgentProvider, concerns)
- Creates example agents and tools
- Creates ChatResponseJob

## Benefits

1. **No Duplication** - RubyLLM owns the core chat infrastructure
2. **Separation of Concerns** - Observ adds observability + agent layer
3. **Schema Compatibility** - Automatic inheritance of RubyLLM schema improvements
4. **Easier Maintenance** - Updates to RubyLLM are automatically available
5. **Clear Ownership** - RubyLLM = chat infrastructure, Observ = observability + agents

## Schema Benefits

By using RubyLLM's schema, we automatically get:

- **Messages table**: `content_raw`, `cached_tokens`, `cache_creation_tokens` (v1.9+)
- **Models table**: Rich model registry with capabilities, pricing, modalities
- **Tool calls table**: JSON-based arguments (more flexible than separate columns)
- **Future improvements**: Any RubyLLM schema updates are inherited

## Error Handling

The generator now provides helpful error messages:

### Missing RubyLLM gem
```
RubyLLM gem not found!

This generator requires RubyLLM to be installed first.

Please run:
  1. Add to Gemfile: gem 'ruby_llm'
  2. bundle install
  3. rails generate ruby_llm:install
  4. rails db:migrate
  5. rails ruby_llm:load_models

Then run this generator again.
```

### Missing RubyLLM models
```
RubyLLM models not found: Chat, Message, ToolCall, Model

This generator requires ruby_llm:install to be run first.

Please run:
  1. rails generate ruby_llm:install
  2. rails db:migrate
  3. rails ruby_llm:load_models

Then run this generator again.
```

## Documentation Updates

- Updated `CHAT_INSTALLATION.md` with new installation flow
- Added "Quick Reference: Installation Order" section
- Updated troubleshooting section
- Updated README.md with RubyLLM prerequisites

## Testing

To test the updated generator on a fresh Rails app:

```bash
# Create new Rails app
rails new test_app
cd test_app

# Add gems
echo "gem 'ruby_llm'" >> Gemfile
echo "gem 'observ', path: '../observ'" >> Gemfile
bundle install

# Follow installation flow
rails generate ruby_llm:install
rails db:migrate
rails ruby_llm:load_models

rails generate observ:install
rails db:migrate

rails generate observ:install:chat
rails db:migrate

# Verify
rails console
> Chat.acts_as_chat
> Message.acts_as_message
> Chat.new.respond_to?(:agent_class)
```

## Migration Path for Existing Apps

For apps that already ran the old `observ:install:chat`:

**Option 1: Clean slate** (recommended for development)
```bash
# Drop and recreate database
rails db:drop db:create db:migrate
```

**Option 2: Manual migration** (for production with data)
1. Models are already created, just need to ensure RubyLLM gem is installed
2. No migration changes needed (schemas are compatible)
3. Update model files to use the enhanced versions if desired

## Future Considerations

1. **Custom model names**: RubyLLM supports custom model names via generator arguments. Observ should support enhancing custom-named models.

2. **Namespace support**: RubyLLM supports namespaced models (e.g., `Admin::Chat`). Observ generator should detect and handle these.

3. **Version compatibility**: Document which RubyLLM versions are compatible with which Observ versions.

4. **Generator composition**: Consider whether `observ:install:chat` should automatically run `ruby_llm:install` if not already done (with confirmation prompt).

## References

- RubyLLM documentation: https://rubyllm.com
- RubyLLM install generator: https://github.com/crmne/ruby_llm/blob/main/lib/generators/ruby_llm/install/install_generator.rb
- Chat Installation Guide: docs/CHAT_INSTALLATION.md
