# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-11-02

### Added

- Initial release of Observ Rails engine
- **Core Models**:
  - `Observ::Session` - Session tracking with aggregated metrics
  - `Observ::Trace` - Individual execution traces
  - `Observ::Observation` - Base observation class (STI)
  - `Observ::Generation` - LLM generation observations
  - `Observ::Span` - Generic span observations
  - `Observ::Annotation` - User annotations on traces/sessions
  - `Observ::Prompt` - Prompt version management with state machine

- **Controllers & UI**:
  - Dashboard with metrics and cost analysis
  - Session listing and details
  - Trace exploration and search
  - Observation filtering (generations/spans)
  - Annotation CRUD and CSV export
  - Prompt management UI with version control
  - Dedicated Observ layout with navigation

- **Services**:
  - `ChatInstrumenter` - RubyLLM instrumentation (460 lines)
  - `PromptManager` - Advanced prompt retrieval and caching (280 lines)
  - `AgentSelectionService` - Agent-based prompt selection

- **Caching System**:
  - Intelligent caching with configurable TTL
  - Automatic cache invalidation on prompt changes
  - Cache warming for critical prompts
  - Cache monitoring and statistics
  - Batch fetching for multiple prompts
  - Supports Redis, Memory, or any Rails cache store

- **Concerns**:
  - `ObservabilityInstrumentation` - Enables automatic observability tracking
  - `TraceAssociation` - Adds trace relationship to models

- **Frontend**:
  - 7 Stimulus controllers for interactive UI
  - 13 SCSS files for styling
  - Responsive design
  - Real-time updates with Turbo Streams

- **Configuration**:
  - Flexible configuration system
  - Environment-based feature flags
  - Configurable cache backends
  - UI customization options

- **Testing**:
  - Comprehensive test coverage (24+ spec files)
  - RSpec configuration
  - Factory Bot factories for all models
  - Feature specs for critical user journeys

### Features

- **Optional RubyLLM Integration**: Automatic instrumentation when RubyLLM is detected
- **State Machine**: Prompt lifecycle management (draft → production → archived)
- **Pagination**: Kaminari integration for large datasets
- **Cost Tracking**: Real-time cost analysis by model and provider
- **Token Metrics**: Input/output token tracking with caching details
- **Metadata Support**: Flexible JSON metadata on all models
- **CSV Export**: Export annotations for external analysis

### Technical Details

- Rails >= 7.0 support
- Isolated namespace for clean integration
- Pluggable architecture for easy customization
- Database migrations included
- Asset pipeline integration (Vite/Sprockets compatible)

### Dependencies

- `rails >= 7.0, < 9.0`
- `kaminari ~> 1.2`
- `aasm ~> 5.5`

### Development Dependencies

- `rspec-rails ~> 7.0`
- `factory_bot_rails ~> 6.0`
- `shoulda-matchers ~> 6.0`
- `faker ~> 3.0`
- `capybara`
- `sqlite3 >= 1.4`

## [Unreleased]

### Planned for v0.2.0

- Langfuse export integration
- Additional provider support (Anthropic, Gemini)
- Enhanced analytics dashboard
- API for programmatic access
- WebSocket support for real-time updates
- Advanced filtering and search
- Custom metric definitions
- Alert system for cost/usage thresholds

---

[0.1.0]: https://github.com/yourusername/observ/releases/tag/v0.1.0
[Unreleased]: https://github.com/yourusername/observ/compare/v0.1.0...HEAD
