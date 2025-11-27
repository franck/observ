# Observ

A Rails engine providing comprehensive observability for LLM-powered applications, including session tracking, trace analysis, prompt management, and cost monitoring.

## Features

### Core Observability Features
- **Session Tracking**: Automatically track user sessions across LLM interactions
- **Trace Analysis**: Detailed execution traces with token usage and cost metrics
- **Prompt Management**: Version-controlled prompts with state machine (draft/production/archived)
- **Cost Monitoring**: Real-time tracking of API costs across models and providers
- **Annotation Tools**: Add notes and export data for analysis
- **Advanced Caching**: Sophisticated caching system with Redis support and monitoring

### Optional Chat/Agent Testing Feature
- **Agent Testing UI**: Interactive chat interface for testing LLM agents at `/observ/chats`
- **Agent Management**: Create, select, and configure different agents
- **Message Streaming**: Real-time response streaming with Turbo
- **Tool Visualization**: See tool calls in action
- **RubyLLM Integration**: Full integration with RubyLLM gem for agent development

## Installation

Observ offers **two installation modes**: Core (observability only) or Core + Chat (with agent testing).

### Core Installation (Recommended for Most Users)

For LLM observability without the chat UI:

**1. Add to Gemfile:**

```ruby
gem "observ"
```

**2. Install:**

```bash
bundle install
rails observ:install:migrations
rails db:migrate
rails generate observ:install
```

**What you get:**
- Dashboard at `/observ`
- Session tracking and analysis
- Trace visualization
- Prompt management
- Cost monitoring
- Annotation tools

**No chat UI** - Perfect if you're instrumenting an existing application and just want observability.

---

### Core + Chat Installation (For Agent Testing)

For full observability + interactive agent testing UI:

**1. Add to Gemfile:**

```ruby
gem "observ"
gem "ruby_llm"  # Required for chat feature
```

**2. Install core + chat:**

```bash
bundle install

# Install RubyLLM infrastructure first
rails generate ruby_llm:install
rails db:migrate
rails ruby_llm:load_models

# Then install Observ
rails observ:install:migrations
rails generate observ:install         # Core features
rails generate observ:install:chat    # Chat feature
rails db:migrate
```

**What you get:**
- Everything from Core installation
- Chat UI at `/observ/chats`
- Agent testing interface
- Observ enhancements on RubyLLM infrastructure
- Example agents and tools

See **Creating Agents and Services** in `docs/creating-agents-and-services.md` for detailed setup.

---

### Asset Installation

After running either installation mode:

```bash
# For first-time installation (recommended)
rails generate observ:install

# Or use the rake task
rails observ:install_assets
```

This will:
- Show you the destination paths where assets will be copied
- Ask for confirmation before proceeding
- Automatically mount the engine in `config/routes.rb` (if not already present)
- Copy Observ stylesheets to `app/javascript/stylesheets/observ`
- Copy Observ JavaScript Stimulus controllers to `app/javascript/controllers/observ`
- Generate index files for easy importing
- Check if controllers are properly registered in your application

**Custom asset destinations:**

```bash
# Install to custom locations
rails generate observ:install --styles-dest=app/assets/stylesheets/observ --js-dest=app/javascript/controllers/custom

# Or with rake task
rails observ:install_assets[app/assets/stylesheets/observ,app/javascript/controllers/custom]
```

**Skip confirmation (useful for CI/CD or automated scripts):**

```bash
# Skip confirmation prompt
rails generate observ:install --force

# With custom destinations
rails generate observ:install --force --styles-dest=custom/path --js-dest=custom/path

# Skip automatic route mounting (if you want to mount manually)
rails generate observ:install --skip-routes
```

**Updating assets:**

When you update the Observ gem, sync the latest assets:

```bash
rails observ:sync_assets
```

This will update only changed files without regenerating index files.

## Configuration

### 1. Mount the Engine (Automatic)

The install generator automatically adds the engine mount to `config/routes.rb`:

```ruby
mount Observ::Engine, at: "/observ"
```

This makes Observ available at `/observ` in your application.

If you used `--skip-routes` during installation, manually add the route to `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount Observ::Engine, at: "/observ"
  
  # Your other routes...
end
```

### 2. Configure the Engine

Create `config/initializers/observ.rb`:

```ruby
Observ.configure do |config|
  # Prompt management
  config.prompt_management_enabled = true
  config.prompt_max_versions = 100
  config.prompt_default_state = :production
  config.prompt_allow_production_deletion = false
  config.prompt_fallback_behavior = :raise # or :return_nil, :use_fallback
  
  # Caching configuration
  config.prompt_cache_ttl = 300 # 5 minutes (0 to disable)
  config.prompt_cache_store = :redis_cache_store # or :memory_store
  config.prompt_cache_namespace = "observ:prompt"
  
  # Cache warming (load critical prompts on boot)
  config.prompt_cache_warming_enabled = true
  config.prompt_cache_critical_prompts = ["research_agent", "rpg_agent"]
  
  # Cache monitoring (track hit rates)
  config.prompt_cache_monitoring_enabled = true
  
  # UI configuration
  config.back_to_app_path = -> { Rails.application.routes.url_helpers.root_path }
  config.back_to_app_label = "← Back to App"
  
  # Chat UI (auto-detects if Chat model exists with acts_as_chat)
  # Manually override if needed:
  # config.chat_ui_enabled = true
end
```

### 3. Configure Observability Features

The `observ:install:chat` generator automatically creates `config/initializers/observability.rb`:

```ruby
Rails.application.configure do
  config.observability = ActiveSupport::OrderedOptions.new
  
  # Enable observability instrumentation
  # When enabled, sessions, traces, and observations are automatically tracked
  config.observability.enabled = true
  
  # Automatically instrument RubyLLM chats with observability
  # When enabled, LLM calls, tool usage, and metrics are tracked
  config.observability.auto_instrument_chats = true
  
  # Enable debug logging for observability metrics
  # When enabled, job completion metrics (tokens, cost) will be logged
  config.observability.debug = Rails.env.development?
end
```

**Environment-based configuration:**

```ruby
# Use environment variables for production
config.observability.enabled = ENV.fetch("OBSERVABILITY_ENABLED", "true") == "true"
config.observability.auto_instrument_chats = ENV.fetch("AUTO_INSTRUMENT", "true") == "true"
config.observability.debug = ENV.fetch("OBSERVABILITY_DEBUG", "false") == "true"
```

**Important:** 
- `enabled` must be `true` for observability sessions to be created
- `auto_instrument_chats` must be `true` for automatic LLM call tracking
- Without these settings, observability features will be disabled

### 4. Configure RubyLLM (Chat Feature Only)

**Skip this if you're using Core installation only.**

If you installed the chat feature, create `config/initializers/ruby_llm.rb`:

```ruby
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.default_model = "gpt-4o-mini"
  
  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
  
  # Optional: Other providers
  # config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  # config.google_api_key = ENV['GOOGLE_API_KEY']
end
```

### 5. Add Concerns to Your Models (Chat Feature Only)

**Skip this if you're using Core installation only.**

The `observ:install:chat` generator creates these models automatically. If you're manually setting up:

```ruby
class Chat < ApplicationRecord
  include Observ::ObservabilityInstrumentation
  
  # Your existing code...
end
```

This adds:
- `observ_session` association
- Automatic session creation on model creation
- `ask_with_observability` method for tracked LLM calls

For message models (optional, for trace linking):

```ruby
class Message < ApplicationRecord
  include Observ::TraceAssociation
  
  # Your existing code...
end
```

This adds `has_many :traces` relationship.

**Note:** The `observ:install:chat` generator handles all of this automatically, including migrations!

## Usage

### Basic Usage (Core Features)

Once installed, Observ automatically tracks:

1. **Sessions**: Created when your instrumented models are created
2. **Traces**: Captured when you call LLM methods (if using RubyLLM)
3. **Observations**: Generations and spans are recorded with metadata

Visit `/observ` in your browser to see:
- Dashboard with metrics and cost analysis
- Session history
- Trace details
- Prompt management UI

### Chat Feature Usage (If Installed)

If you installed the chat feature with `rails generate observ:install:chat`:

**1. Visit `/observ/chats`**

**2. Create a new chat:**
   - Click "New Chat"
   - Select an agent (e.g., SimpleAgent)
   - Start chatting!

**3. Create custom agents:**

```ruby
# app/agents/my_agent.rb
class MyAgent < BaseAgent
  include AgentSelectable
  
  def self.display_name
    "My Custom Agent"
  end
  
  def self.system_prompt
    "You are a helpful assistant that..."
  end
  
  def self.default_model
    "gpt-4o-mini"
  end
end
```

**4. View session data:**
   - All chat interactions appear in `/observ/sessions`
   - Full observability of tokens, costs, and tool calls

See `docs/creating-agents-and-services.md` for complete documentation on creating agents.

### Phase Tracking (Optional Chat Feature)

For multi-phase agent workflows (e.g., scoping → research → writing), add phase tracking:

**1. Add phase tracking to your installation:**

```bash
# During initial installation
rails generate observ:install:chat --with-phase-tracking

# Or add to existing installation
rails generate observ:add_phase_tracking
rails db:migrate
```

**2. Use phase transitions in your agents:**

```ruby
# app/agents/research_agent.rb
class ResearchAgent < BaseAgent
  def perform_research(chat, query)
    # Transition to research phase
    chat.transition_to_phase('research')
    
    # Do research work...
    results = research(query)
    
    # Transition to writing phase
    chat.transition_to_phase('writing', depth: 'comprehensive')
    
    # Generate report...
  end
end
```

**3. Check current phase:**

```ruby
chat.current_phase  # => 'research'
chat.in_phase?('research')  # => true
```

**4. (Optional) Define allowed phases:**

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  include Observ::ObservabilityInstrumentation
  include Observ::AgentPhaseable
  
  def allowed_phases
    %w[scoping research writing review]
  end
end
```

**Benefits:**
- Phase transitions are automatically tracked in observability metadata
- View phase progression in `/observ/sessions`
- Analyze time and cost per phase
- Debug which phase causes issues

**Phase data in observability:**

All phase transitions are captured in session metadata:
```ruby
session.metadata
# => {
#   "agent_type" => "ResearchAgent",
#   "chat_id" => 42,
#   "agent_phase" => "writing",
#   "phase_transition" => "research -> writing",
#   "depth" => "comprehensive"
# }
```

### Extending Observability Metadata (Advanced)

You can extend observability metadata by overriding hook methods in your Chat model:

```ruby
# app/models/chat.rb
class Chat < ApplicationRecord
  include Observ::ObservabilityInstrumentation
  
  # Override to add custom metadata to session
  def observability_metadata
    super.merge(
      user_id: user_id,
      subscription_tier: user.subscription_tier,
      feature_flags: enabled_features
    )
  end
  
  # Override to add custom context to instrumenter
  def observability_context
    super.merge(
      locale: I18n.locale,
      timezone: Time.zone.name
    )
  end
end
```

This allows you to:
- Track user-specific information
- Add business logic metadata
- Include feature flags for A/B testing analysis
- Track localization and timezone data

**Note:** The `AgentPhaseable` concern uses these same hooks to inject phase data.

### Manual Instrumentation

If not using RubyLLM, you can manually create traces:

```ruby
session = Observ::Session.create(
  session_id: SecureRandom.uuid,
  user_id: current_user.id,
  metadata: { agent_type: "custom" }
)

trace = session.traces.create(
  name: "Custom Operation",
  start_time: Time.current
)

# ... do work ...

trace.update(
  end_time: Time.current,
  metadata: { result: "success" }
)
```

### Prompt Management

Fetch prompts in your code:

```ruby
# Fetch production version
prompt = Observ::PromptManager.fetch(name: "research_agent", state: :production)
content = prompt.content

# Fetch specific version
prompt = Observ::PromptManager.fetch(name: "research_agent", version: 5)

# With caching (automatic)
prompt = Observ::PromptManager.fetch(name: "research_agent") # Cached for 5 min
```

Cache management:

```ruby
# Check cache stats
Observ::PromptManager.cache_stats("research_agent")
# => { hits: 145, misses: 12, total: 157, hit_rate: 92.36 }

# Invalidate cache
Observ::PromptManager.invalidate_cache(name: "research_agent")

# Warm cache (done automatically on boot if configured)
Observ::PromptManager.warm_cache(["agent1", "agent2"])
```

### Annotations

Add annotations to sessions or traces:

```ruby
session.annotations.create(
  content: "Important insight",
  annotator: "user@example.com",
  tags: ["bug", "performance"]
)

# Export annotations
# Visit /observ/annotations/export in browser
```

### Datasets & Evaluators

Observ includes a dataset and evaluator system for testing LLM outputs against predefined inputs and scoring results.

**Creating a dataset:**

```ruby
# Create a dataset
dataset = Observ::Dataset.create!(
  name: "Article Recommendations Test Set",
  description: "Test cases for article recommendation system"
)

# Add test items
dataset.items.create!(
  input: { user_query: "Recommend articles for someone feeling anxious" },
  expected_output: { recommended_articles: ["art_001", "art_003"] }
)
```

**Running evaluations:**

```ruby
# Create a dataset run
run = dataset.runs.create!(
  name: "GPT-4 baseline",
  model_name: "gpt-4",
  status: :pending
)

# Run items are created when executing your LLM against the dataset
# Each run item links a dataset item to a trace

# Score outputs with built-in evaluators
Observ::Evaluators::ExactMatchEvaluator.new.evaluate(run_item)
Observ::Evaluators::ContainsEvaluator.new(keywords: ["anxiety"]).evaluate(run_item)
```

**Built-in evaluators:**
- `ExactMatchEvaluator` - Exact string match against expected output
- `ContainsEvaluator` - Check if output contains specific keywords
- `JsonStructureEvaluator` - Validate JSON structure
- `LlmJudgeEvaluator` - Use an LLM to score output quality

Visit `/observ/datasets` to manage datasets and view run results in the UI.

See `docs/dataset_and_evaluator_feature.md` for complete documentation.

## Asset Management

Observ provides several tools for managing assets in your Rails application:

### Generators

```bash
# Install assets for the first time (recommended)
rails generate observ:install

# Install to custom locations
rails generate observ:install --styles-dest=custom/path --js-dest=custom/controllers

# Skip index file generation
rails generate observ:install --skip-index
```

### Rake Tasks

```bash
# Install assets (with index file generation)
rails observ:install_assets
rails observ:install  # shorthand

# Sync assets (update only, no index generation)
rails observ:sync_assets
rails observ:sync  # shorthand

# Custom destinations
rails observ:install_assets[app/assets/stylesheets/observ,app/javascript/controllers/custom]
```

### Programmatic API

You can also use the Ruby API directly:

```ruby
require 'observ/asset_installer'

installer = Observ::AssetInstaller.new(
  gem_root: Observ::Engine.root,
  app_root: Rails.root
)

# Full installation with index generation
result = installer.install(
  styles_dest: 'app/javascript/stylesheets/observ',
  js_dest: 'app/javascript/controllers/observ',
  generate_index: true
)

# Just sync existing files
result = installer.sync(
  styles_dest: 'app/javascript/stylesheets/observ',
  js_dest: 'app/javascript/controllers/observ'
)
```

## Development

After checking out the repo, run:

```bash
cd observ
bundle install
```

Run tests:

```bash
bundle exec rspec
```

## Architecture

Observ uses:
- **Isolated namespace**: All classes under `Observ::` module
- **Engine pattern**: Mountable Rails engine for easy integration
- **STI for observations**: `Observ::Generation` and `Observ::Span` inherit from `Observ::Observation`
- **AASM for state machine**: Prompt lifecycle management
- **Kaminari for pagination**: Session and trace listings
- **Stimulus controllers**: Interactive UI components
- **Rails.cache**: Pluggable caching backend (Redis, Memory, etc.)
- **Conditional routes**: Chat routes only mount if Chat model exists (Phase 1)
- **Global namespace**: Controllers use `::Chat` and `::Message` for host app models

## Optional Dependencies

### Core Features
- **Redis**: For production caching (optional, can use memory cache)

### Chat Feature (Optional Add-on)
- **RubyLLM**: Required for chat/agent testing feature
- Installed with `rails generate observ:install:chat`
- See `docs/creating-agents-and-services.md` for agent documentation

## Testing

Disable observability in tests by default:

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.before(:each) do
    allow(Rails.configuration.observability).to receive(:enabled).and_return(false)
  end

  # Enable for specific tests
  config.before(:each, observability: true) do
    allow(Rails.configuration.observability).to receive(:enabled).and_return(true)
  end
end
```

## Troubleshooting

### Routes not found

Make sure you've mounted the engine in `config/routes.rb` and restarted your server.

### Assets not loading

First, make sure you've installed the assets:

```bash
rails generate observ:install
```

Then ensure you've imported them in your application:

**For JavaScript/Vite/esbuild setups:**

Add to `app/javascript/application.js`:
```javascript
import 'observ'
```

And ensure `app/javascript/controllers/index.js` includes:
```javascript
import './observ'
```

**For Sprockets (traditional asset pipeline):**

Add to `app/assets/stylesheets/application.scss`:
```scss
@use 'observ';
```

Or for older Sass versions:
```scss
@import 'observ';
```

**Verifying Stimulus controllers:**

Check your browser console for any Stimulus connection errors. Observ controllers should register with the `observ--` prefix (e.g., `observ--drawer`, `observ--copy`).

**Syncing after gem updates:**

If you've updated the Observ gem, run:
```bash
rails observ:sync_assets
```

### Concerns not found

The engine loads concerns via initializer. Make sure the gem is properly bundled and the app has restarted.

### Cache not working

Check that:
- `prompt_cache_ttl > 0`
- Rails cache store is configured (Redis recommended for production)
- Rails.cache is working: `Rails.cache.write("test", "value")` / `Rails.cache.read("test")`

### Observability sessions not being created

If chats are created but observability sessions are not:

**1. Check observability is enabled:**

```ruby
rails runner "puts Rails.configuration.observability.enabled.inspect"
# Should output: true
```

If it outputs `nil` or `false`, check `config/initializers/observability.rb` exists and sets:
```ruby
config.observability.enabled = true
```

**2. Check the observability_session_id column exists:**

```ruby
rails runner "puts Chat.column_names.include?('observability_session_id')"
# Should output: true
```

If it outputs `false`, you're missing the migration. Run:
```bash
rails generate migration AddObservabilitySessionIdToChats observability_session_id:string:index
rails db:migrate
```

**3. Check for errors in logs:**

```bash
tail -f log/development.log | grep Observability
```

Look for `[Observability] Failed to initialize session:` messages.

**4. Verify the concern is included:**

```ruby
rails runner "puts Chat.included_modules.include?(Observ::ObservabilityInstrumentation)"
# Should output: true
```

### Phase tracking errors

If you see `AgentPhaseable requires a 'current_phase' column`:

You're trying to use phase tracking without the database column. Run:

```bash
rails generate observ:add_phase_tracking
rails db:migrate
```

Or remove `include Observ::AgentPhaseable` from your Chat model if you don't need phase tracking.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Version

Current version: 0.5.1
