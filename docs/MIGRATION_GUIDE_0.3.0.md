# Migration Guide: Upgrading to Observ 0.3.0

This guide helps you upgrade from Observ 0.1.x/0.2.x to 0.3.0.

## Overview

Version 0.3.0 makes the chat/agent testing feature **optional**, improving flexibility and reducing setup friction for users who only need core observability features.

## Summary of Changes

### What Changed
- Chat routes now conditionally mount (only if Chat model exists)
- Controllers use global namespace (`::Chat`, `::Message`)
- New generator: `rails generate observ:install:chat`
- Two-tier installation (Core vs Core + Chat)

### What Didn't Change
- Core observability features (Sessions, Traces, Observations, Prompts)
- Existing API and configuration
- Database schema
- Frontend assets

## Who Needs to Take Action?

### ✅ No Action Needed

**You have an existing app with Chat/RubyLLM:**

Your app will continue to work **exactly as before** with zero changes:
- Routes auto-detect and mount
- All functionality preserved
- 100% backward compatible

**Verification:**
```bash
bin/rails routes | grep chats
# Should show: /observ/chats, /observ/chats/new, etc.
```

### ⚠️ Action May Be Needed

**You're installing Observ in a new app:**

Choose your installation mode (see Installation Modes below).

## Installation Modes

### Mode 1: Core Only (New in 0.3.0)

For pure observability without chat UI:

```bash
# Gemfile
gem "observ"

# Installation
bundle install
rails observ:install:migrations
rails db:migrate
rails generate observ:install
```

**What you get:**
- Dashboard, Sessions, Traces, Observations, Prompts
- No chat UI or agent testing

**Routes available:**
- `/observ` - Dashboard
- `/observ/sessions` - Session tracking
- `/observ/traces` - Trace analysis
- `/observ/prompts` - Prompt management

**Routes NOT available:**
- `/observ/chats` - Not mounted (404)

### Mode 2: Core + Chat (Existing Behavior)

For full observability + agent testing:

```bash
# Gemfile
gem "observ"
gem "ruby_llm"

# Installation
bundle install
rails observ:install:migrations
rails generate observ:install
rails generate observ:install:chat  # ⭐ New!
rails db:migrate
```

**What you get:**
- Everything from Mode 1
- Chat UI at `/observ/chats`
- Agent testing capabilities
- Full RubyLLM infrastructure

## Upgrade Scenarios

### Scenario 1: Existing App with Chat (Most Common)

**Before (0.2.0):**
- Chat model exists
- RubyLLM integrated
- `/observ/chats` works

**After (0.3.0):**
- No changes needed
- Update `Gemfile`: `gem "observ", "~> 0.3.0"`
- Run `bundle update observ`
- Restart server
- Everything continues to work

**Why it works:**
- Routes auto-detect Chat model
- Conditional mounting succeeds
- Backward compatible

### Scenario 2: New App - Core Only

**Goal:** Just want observability, no chat

**Steps:**
```bash
# 1. Add to Gemfile
gem "observ", "~> 0.3.0"

# 2. Install
bundle install
rails observ:install:migrations
rails db:migrate
rails generate observ:install

# 3. Done!
```

**Result:**
- Core features available
- No chat routes
- Smaller footprint

### Scenario 3: New App - Full Features

**Goal:** Observability + agent testing

**Steps:**
```bash
# 1. Add to Gemfile
gem "observ", "~> 0.3.0"
gem "ruby_llm"

# 2. Install core
bundle install
rails observ:install:migrations
rails generate observ:install

# 3. Install chat feature
rails generate observ:install:chat

# 4. Run migrations
rails db:migrate

# 5. Configure RubyLLM
# Create config/initializers/ruby_llm.rb
```

See [Chat Installation Guide](CHAT_INSTALLATION.md) for details.

## Breaking Changes?

**None for existing apps!**

The changes are backward compatible. If you have:
- Chat model with `acts_as_chat`
- RubyLLM gem installed
- Observability concerns included

Then 0.3.0 works exactly like 0.2.0.

### Technically Breaking (But Handled)

1. **Routes Conditional** - Routes only mount if Chat exists
   - **Impact:** None for existing apps (Chat already exists)
   - **Auto-handled:** Detection is automatic

2. **Namespace Changes** - Controllers use `::Chat`
   - **Impact:** None (transparent to users)
   - **Auto-handled:** Works with any namespace

## Troubleshooting

### Chat routes return 404

**Problem:** `/observ/chats` returns 404 after upgrade

**Cause:** Routes didn't mount (Chat model not detected)

**Solution:**

1. Check if Chat model exists:
```bash
bin/rails console
> defined?(::Chat)
# Should return "constant"
```

2. Check if it has acts_as_chat:
```bash
> ::Chat.respond_to?(:acts_as_chat)
# Should return true
```

3. If either fails, run the generator:
```bash
rails generate observ:install:chat
rails db:migrate
```

4. Restart server

### Generator creates duplicate files

**Problem:** `rails generate observ:install:chat` tries to overwrite existing files

**Cause:** You already have Chat, Message, etc.

**Solution:**

Skip migrations if they exist:
```bash
rails generate observ:install:chat --skip-migrations
```

Or manually skip specific files when prompted.

### Observability not working after upgrade

**Problem:** Chats don't create sessions/traces

**Cause:** Configuration not loaded

**Solution:**

Check `config/initializers/observability.rb`:
```ruby
Rails.application.config.observability.enabled = true
Rails.application.config.observability.auto_instrument_chats = true
```

Restart server.

## Testing Your Upgrade

### Checklist

After upgrading, verify:

- [ ] `bundle list observ` shows version 0.3.0
- [ ] Server starts without errors
- [ ] `/observ` dashboard loads
- [ ] `/observ/sessions` shows sessions
- [ ] `/observ/traces` shows traces
- [ ] `/observ/prompts` works (if using prompt management)
- [ ] `/observ/chats` works (if Chat model exists)
- [ ] New chats create sessions (if using chat)
- [ ] Existing data still visible

### Manual Testing

1. **Visit dashboard:**
   ```
   http://localhost:3000/observ
   ```
   Should load without errors.

2. **Check routes:**
   ```bash
   bin/rails routes | grep observ
   ```
   Should show core routes + chat routes (if Chat exists).

3. **Test chat (if applicable):**
   - Visit `/observ/chats`
   - Create new chat
   - Send message
   - Verify session created
   - Check trace recorded

## Rollback Plan

If issues arise, rollback is simple:

```ruby
# Gemfile
gem "observ", "~> 0.2.0"
```

```bash
bundle update observ
bin/rails restart
```

All 0.2.0 functionality preserved in 0.3.0, so rollback is safe.

## New Features to Try

### 1. Core-Only Installation

Try Observ in a fresh app without RubyLLM:
```bash
rails new myapp
cd myapp
# Add gem "observ"
bundle install
rails observ:install:migrations && rails db:migrate
rails generate observ:install
```

Visit `/observ` - works without Chat!

### 2. Chat Generator

If you want chat features later:
```bash
# Add gem "ruby_llm" to Gemfile
bundle install
rails generate observ:install:chat
rails db:migrate
```

Instant agent testing setup!

### 3. Custom Agents

Create agents easily with generated infrastructure:
```ruby
# app/agents/my_agent.rb
class MyAgent < BaseAgent
  include AgentSelectable
  
  def self.display_name
    "My Agent"
  end
  
  def self.system_prompt
    "You are..."
  end
  
  def self.default_model
    "gpt-4o-mini"
  end
end
```

Appears in `/observ/chats` dropdown automatically!

## Getting Help

### Resources

- [Main README](../README.md) - Overview and features
- [Chat Installation Guide](CHAT_INSTALLATION.md) - Detailed chat setup
- [CHANGELOG](../CHANGELOG.md) - Full change log
- [Phase 1 Completion](PHASE_1_COMPLETION.md) - Technical details
- [Phase 2 Completion](PHASE_2_COMPLETION.md) - Generator details

### Support

- GitHub Issues: https://github.com/franck/observ/issues
- Check existing issues for solutions
- Report bugs with reproduction steps

## Summary

**For most users:** Update gem version, restart server, done!

**For new users:** Choose Core or Core + Chat installation.

**Breaking changes:** None for existing apps.

**New features:** Optional chat, better flexibility, improved DX.

Happy observing! 🎉
