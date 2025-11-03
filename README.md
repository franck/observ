# Observ

A Rails engine providing comprehensive observability for LLM-powered applications, including session tracking, trace analysis, prompt management, and cost monitoring.

## Features

- **Session Tracking**: Automatically track user sessions across LLM interactions
- **Trace Analysis**: Detailed execution traces with token usage and cost metrics
- **Prompt Management**: Version-controlled prompts with state machine (draft/production/archived)
- **Cost Monitoring**: Real-time tracking of API costs across models and providers
- **Annotation Tools**: Add notes and export data for analysis
- **Advanced Caching**: Sophisticated caching system with Redis support and monitoring
- **RubyLLM Integration**: Optional automatic instrumentation for RubyLLM gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem "observ", path: "observ" # Or git/rubygems source
```

And then execute:

```bash
bundle install
```

Install and run migrations:

```bash
rails observ:install:migrations
rails db:migrate
```

## Configuration

### 1. Mount the Engine

In `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount Observ::Engine, at: "/observ"
  
  # Your other routes...
end
```

This makes Observ available at `/observ` in your application.

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
end
```

### 3. Configure Observability Features

Create `config/initializers/observability.rb`:

```ruby
Rails.application.config.observability = ActiveSupport::OrderedOptions.new

# Enable/disable observability
Rails.application.config.observability.enabled = ENV.fetch("OBSERVABILITY_ENABLED", "true") == "true"

# Auto-instrument RubyLLM chats
Rails.application.config.observability.auto_instrument_chats = ENV.fetch("OBSERVABILITY_AUTO_INSTRUMENT", "true") == "true"

# Debug logging
Rails.application.config.observability.debug = ENV.fetch("OBSERVABILITY_DEBUG", Rails.env.development?.to_s) == "true"
```

### 4. Add Concerns to Your Models

For chat models (or any model that uses LLMs):

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

### 5. Add Database Column

Add `observability_session_id` to models using `ObservabilityInstrumentation`:

```ruby
# Generate migration
rails generate migration AddObservabilityToChats observability_session_id:string

# Or manually:
class AddObservabilityToChats < ActiveRecord::Migration[8.0]
  def change
    add_column :chats, :observability_session_id, :string
    add_index :chats, :observability_session_id
  end
end
```

## Usage

### Basic Usage

Once installed, Observ automatically tracks:

1. **Sessions**: Created when your instrumented models are created
2. **Traces**: Captured when you call LLM methods (if using RubyLLM)
3. **Observations**: Generations and spans are recorded with metadata

Visit `/observ` in your browser to see:
- Dashboard with metrics and cost analysis
- Session history
- Trace details
- Prompt management UI

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

## Optional Dependencies

- **RubyLLM**: For automatic LLM call instrumentation
- **Redis**: For production caching (optional, can use memory cache)

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

Ensure your asset pipeline includes engine assets. For Vite, you may need to import Observ styles and JavaScript.

### Concerns not found

The engine loads concerns via initializer. Make sure the gem is properly bundled and the app has restarted.

### Cache not working

Check that:
- `prompt_cache_ttl > 0`
- Rails cache store is configured (Redis recommended for production)
- Rails.cache is working: `Rails.cache.write("test", "value")` / `Rails.cache.read("test")`

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Version

Current version: 0.1.0
