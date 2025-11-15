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

## [0.1.2] - 2025-11-12

### Added

- **Asset Installation Service Classes**:
  - `Observ::AssetInstaller` - High-level orchestration for asset installation
  - `Observ::AssetSyncer` - File synchronization with change detection
  - `Observ::IndexFileGenerator` - Automatic Stimulus controller index generation

- **Rails Generator**:
  - `rails generate observ:install` - Interactive asset installation
  - Options for custom destinations (--styles-dest, --js-dest)
  - Option to skip index generation (--skip-index)
  - Color-coded output with clear next steps

- **New Rake Tasks**:
  - `rails observ:install_assets` - Full installation with index generation
  - `rails observ:install` - Shorthand alias
  - Enhanced `rails observ:sync_assets` - Now uses service classes

- **Automatic Index File Generation**:
  - Creates `app/javascript/controllers/observ/index.js` with all imports
  - Registers controllers with `observ--` prefix
  - Checks if main controllers index imports Observ
  - Provides actionable suggestions for manual registration

- **Comprehensive Test Coverage**:
  - `spec/lib/observ/asset_installer_spec.rb`
  - `spec/lib/observ/asset_syncer_spec.rb`
  - `spec/lib/observ/index_file_generator_spec.rb`

- **Documentation**:
  - `ASSET_INSTALLATION_IMPROVEMENTS.md` - Technical overview
  - `UPGRADE_GUIDE.md` - Migration guide for existing users
  - Enhanced README with asset management section
  - Improved troubleshooting section

### Changed

- Refactored rake tasks to use service classes (from 160 lines to ~75 lines)
- Improved first-time installation experience
- Better error messages and user guidance

### Improved

- Asset installation now creates necessary index files automatically
- File synchronization only copies changed files
- Better logging with progress indicators
- Enhanced documentation with step-by-step instructions

### Technical

- Extracted business logic from rake tasks to service classes
- Single Responsibility Principle applied throughout
- Dependency injection for better testability
- Comprehensive RSpec coverage for new features

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
