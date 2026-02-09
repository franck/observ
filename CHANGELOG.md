# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.9] - 2026-02-09

### Fixed

- **Engine**: Load `Observ::MarkdownHelper` before the engine initializer runs to avoid boot-time `NameError`

## [0.6.7] - 2025-12-16

### Added

- **Guardrails System**: Automatic evaluation of traces and sessions upon completion
  - `error_span` rule to detect traces with error spans
  - Auto-evaluation triggers for trace and session lifecycle events

- **Extended RubyLLM Observability**:
  - Image generation observability for `RubyLLM.paint` calls
  - Embedding observability for `RubyLLM.embed` calls
  - Transcription observability for `RubyLLM.transcribe` calls
  - Moderation observability for `RubyLLM.moderate` calls
  - Estimated pricing for `gpt-image-1` models

- **Chat UI Improvements**:
  - Typing indicator while AI is processing
  - Markdown rendering for chat messages with dedicated CSS styles
  - Show actual LLM error message instead of generic error

- **Prompt Enhancements**:
  - Mustache variable interpolation support for `NullPrompt`
  - Hybrid config editor with structured fields and JSON validation

- **ModerationGuardrailService**: Automatic session moderation support

### Fixed

- **Instrumenter**: Handle edge case where `respond_to?(:where)` lies
- **Instrumenter**: Use hardcoded pricing for image generation cost calculation
- **Instrumenter**: Handle both ActiveRecord relations and plain Arrays for messages
- **Engine**: Make `MarkdownHelper` available to host app for Turbo broadcasts
- **Chat**: Refactored chat flow to prevent duplicate messages
- **HTTP Status**: Updated from `unprocessable_entity` to `unprocessable_content` for Rails 7.1+

### Documentation

- Added documentation for moderation guardrail implementation
- Documented image generation, transcription, and moderation instrumentation in README
- Marked RubyLLM observability expansion complete

## [0.6.6] - 2025-11-28

### Changed

- **Configuration Simplification**: Removed `back_to_app_label` configuration option
  - The "Back to App" label is now hardcoded in the sidebar
  - Only `back_to_app_path` remains configurable (as a lambda returning a path string)

### Added

- **Configuration Spec**: Comprehensive test coverage for `Observ::Configuration` class

## [0.6.5] - 2025-11-28

### Added

- **ObservableService Concern**: New reusable concern for adding observability to service objects
  - `Observ::Concerns::ObservableService` provides automatic session lifecycle management
  - Supports three modes: auto-create session, use provided session, or disable observability
  - `with_observability` block for automatic session finalization on success/error
  - `instrument_chat` helper for wrapping RubyLLM chat instances
  - Comprehensive documentation in `docs/creating-agents-and-services.md`

## [0.6.4] - 2025-11-28

### Fixed

- **Host App Compatibility**: Changed `Observ::ApplicationController` to inherit from `ActionController::Base` instead of host app's `ApplicationController`
  - Fixes `Pundit::PolicyScopingNotPerformedError` in host apps using Pundit with `verify_policy_scoped`
  - Engine is now fully isolated from host app controller concerns
  - Access control should be handled at route level (e.g., Devise `authenticate` constraints)

## [0.6.3] - 2025-11-28

### Fixed

- **Vite Compatibility**: Removed Sprockets asset path registration from engine
  - The engine no longer adds its stylesheet/javascript paths to `app.config.assets.paths`
  - Fixes `cannot load such file -- sassc` error in host apps using Vite for Sass compilation
  - Host apps now manage how to include the gem's styles using their preferred asset pipeline

## [0.6.2] - 2025-11-27

### Fixed

- Remove redundant `messages/_content` partial from `install_chat` generator
  - The generator was creating `app/views/messages/_content.html.erb` in the host app
  - This file was never used since `MessageEnhancements` references the gem's built-in partial at `observ/messages/content`

## [0.6.1] - 2025-11-27

### Added

- **Vite Entry Point**: Dedicated Vite entry point for isolated asset loading
  - Enables cleaner integration with host application's asset pipeline
  - Better separation of Observ assets from host app assets

## [0.6.0] - 2025-11-27

### Added

- **Dark Theme**: Complete dark theme implementation for the entire UI
  - New color system with CSS custom properties
  - Dark theme support for all components (cards, forms, tables, drawers)
  - Improved contrast and accessibility

- **Sidebar Navigation**: Replaced top navigation bar with collapsible sidebar
  - Better organization of navigation items
  - More screen real estate for content

### Changed

- **Styleguide Compliance**: Updated all views to follow BEM naming conventions
  - Refactored prompts views for consistency
  - Fixed pagination styling across all pages
  - Improved date input styling
  - Better HTML structure throughout

- **README Updates**: Fixed gem name references and updated documentation
  - Changed gem name from `observ` to `rubyllm-observ`
  - Updated version references
  - Fixed broken documentation links
  - Added datasets documentation

### Fixed

- Review queue pagination issues
- Various visual design improvements for stats pages
- Chat messages styling in dark theme
- JSON viewer dark theme support
- Annotations drawer styling

## [0.5.1] - 2025-11-25

### Changed

- Renamed gem from `observ` to `rubyllm-observ`
- Added `lib/rubyllm-observ.rb` shim for proper Bundler auto-require

## [0.5.0] - 2025-11-25

### Added

- **Datasets Feature for LLM Evaluation**: Complete dataset management system for systematic LLM testing
  - `Observ::Dataset` model for organizing test cases
  - `Observ::DatasetItem` model for individual test inputs with expected outputs
  - `Observ::DatasetRun` model for tracking evaluation runs
  - `Observ::DatasetRunItem` model for individual run results
  - `Observ::Score` model for evaluation scores (automated and manual)
  - Full CRUD UI for datasets and dataset items
  - Dataset runs with progress tracking

- **Evaluator System**: Automated evaluation of LLM outputs
  - `Observ::Evaluators::Base` - Base class for custom evaluators
  - `Observ::Evaluators::ExactMatch` - Exact string matching evaluator
  - `Observ::Evaluators::Contains` - Substring matching evaluator
  - `Observ::Evaluators::LlmJudge` - LLM-as-a-judge evaluator for semantic evaluation
  - Async evaluation execution via `DatasetRunnerJob`
  - Configurable evaluators per dataset

- **Review Mode**: Manual scoring interface for human evaluation
  - Simplified score display for manual review
  - Score success partial for review feedback

- **Mustache Templating**: Added Mustache template support to Prompt model
  - Variable interpolation in prompts using `{{variable}}` syntax

- **Interactive JSON Viewer**: Collapsible JSON viewer for trace input/output fields
  - Better visualization of complex nested data

- **Language Detection Agent Example**: Reference implementation for agent development

### Fixed

- Annotations drawer: Added missing partials and fixed namespaced paths
- Asset installer now uses synced index.js correctly
- Prompt version override for model and parameters
- Form namespace issue in prompts form

### Changed

- Removed model select from chat UI
- Comprehensive pagination added across all index pages
- Prompt configuration validation improvements

### Documentation

- Added dataset and evaluator system design documentation
- Added evaluator feature implementation plan
- Added documentation for creating agents and services

## [0.4.0] - 2024-11-17

### Changed

- **BREAKING**: Core agent infrastructure moved into Observ gem with proper namespacing
  - `PromptManagement` → `Observ::PromptManagement`
  - `AgentSelectable` → `Observ::AgentSelectable`
  - `AgentProvider` → `Observ::AgentProvider`
  - All three now live in the gem (no generation needed)
  - Update agents from `include PromptManagement` to `include Observ::PromptManagement`
  - Update agents from `include AgentSelectable` to `include Observ::AgentSelectable`
  - Delete generated files after migration:
    - `app/agents/concerns/prompt_management.rb`
    - `app/agents/concerns/agent_selectable.rb`
    - `app/agents/agent_provider.rb`
  - See [PROMPT_MANAGEMENT_MIGRATION.md](docs/PROMPT_MANAGEMENT_MIGRATION.md) for complete migration guide
- `rails generate observ:install:chat` no longer generates `AgentProvider` or concerns (all built into gem)
- **Model Parameters Architecture**:
  - Parameters now configured via `setup_parameters` hook (called during chat initialization)
  - `chat.ask()` no longer accepts `**model_parameters` argument
  - Parameters automatically extracted from chat instance for observability
  - **Existing apps**: Remove `**agent_class.model_parameters` from all `chat.ask()` calls
- Generator templates updated to use namespaced components:
  - `base_agent.rb.tt` includes `setup_parameters` method
  - `simple_agent.rb.tt` uses `Observ::AgentSelectable`
  - `chat_response_job.rb.tt` now calls `chat.ask(content)` without parameters

### Added

- `Observ::PromptManagement` concern now distributed with gem (no generation needed)
- `Observ::AgentSelectable` concern now distributed with gem (no generation needed)
- `Observ::AgentProvider` service now distributed with gem (no generation needed)
- Model parameters support in `BaseAgent` with `default_model_parameters` and `model_parameters` methods
- `setup_parameters` hook in BaseAgent for configuring chat parameters during initialization
- `ChatEnhancements` now calls `setup_parameters` in `initialize_agent` callback
- Configuration option `agent_path` for customizing agent discovery location
- Comprehensive migration guide for namespace changes

### Fixed

- **Model Parameter Observability**: Parameters now correctly captured in traces and observations
  - `ChatInstrumenter` extracts parameters from chat instance (via `chat.params`)
  - Temperature, max_tokens, and other parameters now visible in UI
- **Model Parameter Type Conversion**: Parameters loaded from database now have correct numeric types
  - `PromptManagement#extract_llm_parameters` converts string values to proper Float/Integer types
  - Fixes OpenAI API errors: "Invalid type for 'temperature': expected a decimal, but got a string"
  - String values like `"0.7"` now converted to `0.7` (Float)
  - String values like `"2000"` now converted to `2000` (Integer)
  - Non-numeric values (arrays, hashes) preserved unchanged
  - Parameters configured once during chat creation (via `initialize_agent` callback)
- **System Prompt Duplication**: Instructions no longer added multiple times on each message
  - `ChatEnhancements#ensure_agent_configured` now only re-applies parameters, not instructions
  - Instructions are set once at chat creation and persist across messages
  - Fixes issue where system prompt appeared multiple times in conversation context
- Agent selector in chat UI now works correctly with namespaced `Observ::AgentSelectable`
  - Fixes issue where agents wouldn't appear in dropdown after namespace migration

### Migration Required

**For existing applications:**

1. **Update ChatResponseJob** (`app/jobs/chat_response_job.rb`):
   ```ruby
   # BEFORE:
   chat.ask(content, **chat.agent_class.model_parameters) do |chunk|
   
   # AFTER:
   chat.ask(content) do |chunk|
   ```

2. **Update Service Files** (any files that call `chat.ask` with parameters):
   - Remove `**AgentClass.model_parameters` from all `ask()` calls
   - Parameters are now set automatically during chat initialization

3. **No changes needed to BaseAgent** - the `model_parameters` method is still used, just called differently internally

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

## [0.3.0] - 2025-11-15

### 🎉 Major: Chat Feature Now Optional

The chat/agent testing feature is now **completely optional**, making Observ more flexible and easier to adopt for pure observability use cases.

### Added

#### Phase 1: Core Engine Fixes
- **Conditional Route Mounting**: Chat routes (`/observ/chats`) only mount if `Chat` model exists with `acts_as_chat`
- **Configuration Option**: Added `config.chat_ui_enabled` (auto-detects Chat model presence)
- **Global Namespace**: Fixed controllers to use `::Chat` and `::Message` for host app models
- **Session Model**: Safe Chat reference with `if defined?(::Chat)` check

#### Phase 2: Install:Chat Generator
- **New Generator**: `rails generate observ:install:chat` for one-command RubyLLM setup
- **Complete Infrastructure Scaffolding**:
  - 6 migration templates (chats, messages, tool_calls, models, references, agent_class_name)
  - 4 model templates (Chat, Message, ToolCall, Model) with Observ concerns
  - Agent infrastructure (BaseAgent, AgentProvider, concerns)
  - Example agent (SimpleAgent) ready to use
  - ChatResponseJob for async message processing
  - ThinkTool example
- **Generator Options**:
  - `--skip-tools` - Skip tool generation
  - `--skip-migrations` - Skip migrations
  - `--skip-job` - Skip job generation
- **Smart Detection**: Checks for RubyLLM gem and existing Chat model
- **Comprehensive Documentation**: Added `docs/CHAT_INSTALLATION.md` (370+ lines)

#### Phase 3: Documentation Updates
- **Two-Tier Installation**: Clear separation of Core vs Core + Chat
- **Updated README**: Restructured installation section with feature comparison
- **Migration Guide**: Help for existing users
- **Architecture Documentation**: Explained conditional routing and namespace handling

### Changed

#### Breaking Changes (Backward Compatible!)
- **Chat Routes**: Now conditionally mounted (auto-detected, no action needed for existing apps)
- **Controllers**: Use global namespace (`::Chat`, `::Message`) instead of implicit lookup
- **Installation Flow**: New two-tier approach (Core-only or Core + Chat)

**Note:** Existing apps with Chat model continue to work without changes. The Chat model is auto-detected and routes mount automatically.

### Fixed

- **NameError Fixed**: `uninitialized constant Observ::ChatsController::Chat` no longer occurs
- **500 Errors**: `/observ/chats` no longer returns 500 in fresh installations without Chat
- **Namespace Issues**: Proper global namespace resolution for host app models

### Documentation

- Added `docs/PHASE_1_COMPLETION.md` - Core engine fixes summary
- Added `docs/PHASE_2_COMPLETION.md` - Generator implementation details  
- Added `docs/PHASE_3_COMPLETION.md` - Documentation and release notes
- Added `docs/CHAT_INSTALLATION.md` - Complete chat feature guide
- Updated main README with two-tier installation
- Enhanced troubleshooting section

### Migration Guide for Existing Users

**If you have an existing app with Chat/RubyLLM:**

No action needed! Your app will continue to work exactly as before:
- Chat routes auto-detect and mount
- All existing functionality preserved
- Zero breaking changes

**If you want to use Observ in a new app:**

Choose your installation mode:

**Option 1: Core Only** (observability without chat)
```bash
gem "observ"
rails observ:install:migrations
rails db:migrate
rails generate observ:install
```

**Option 2: Core + Chat** (with agent testing)
```bash
gem "observ"
gem "ruby_llm"
rails observ:install:migrations
rails generate observ:install
rails generate observ:install:chat  # ⭐ New!
rails db:migrate
```

### Technical Details

#### Files Modified (Phase 1)
- `app/controllers/observ/chats_controller.rb` - Fixed namespace (4 locations)
- `app/controllers/observ/messages_controller.rb` - Fixed namespace (2 locations)
- `app/models/observ/session.rb` - Safe Chat reference
- `config/routes.rb` - Conditional route mounting
- `lib/observ/configuration.rb` - Added `chat_ui_enabled` config

#### Files Created (Phase 2)
- `lib/generators/observ/install_chat/install_chat_generator.rb` (219 lines)
- 17 template files (migrations, models, agents, jobs, tools)
- `docs/CHAT_INSTALLATION.md` (370+ lines)

#### Total Changes
- **5 files modified** (Phase 1)
- **19 files created** (Phase 2)
- **3 documentation files updated** (Phase 3)
- **27 total files changed**

### Improvements

- ✅ **Better Developer Experience**: Clear installation paths
- ✅ **Reduced Friction**: Core features work out-of-the-box
- ✅ **Flexibility**: Optional chat feature when needed
- ✅ **Graceful Degradation**: Works with or without RubyLLM
- ✅ **Production Ready**: All generated code includes error handling and observability

### Dependencies

No changes to core dependencies:
- `rails >= 7.0, < 9.0`
- `kaminari ~> 1.2`
- `aasm ~> 5.5`

Chat feature adds (optional):
- `ruby_llm` - Only needed if using `rails generate observ:install:chat`

## [Unreleased]

## [0.6.0] - 2025-11-27

### Added

- **Dark Theme**: Complete dark theme implementation for the entire UI
  - New color system with CSS custom properties
  - Dark theme support for all components (cards, forms, tables, drawers)
  - Improved contrast and accessibility

- **Sidebar Navigation**: Replaced top navigation bar with collapsible sidebar
  - Better organization of navigation items
  - More screen real estate for content

### Changed

- **Styleguide Compliance**: Updated all views to follow BEM naming conventions
  - Refactored prompts views for consistency
  - Fixed pagination styling across all pages
  - Improved date input styling
  - Better HTML structure throughout

- **README Updates**: Fixed gem name references and updated documentation
  - Changed gem name from `observ` to `rubyllm-observ`
  - Updated version references
  - Fixed broken documentation links
  - Added datasets documentation

### Fixed

- Review queue pagination issues
- Various visual design improvements for stats pages
- Chat messages styling in dark theme
- JSON viewer dark theme support
- Annotations drawer styling

### Planned for Future Versions

- Langfuse export integration
- Additional provider support (Anthropic, Gemini)
- Enhanced analytics dashboard
- API for programmatic access
- WebSocket support for real-time updates
- Advanced filtering and search
- Custom metric definitions
- Alert system for cost/usage thresholds
- More example agents (ResearchAgent, SummarizationAgent)
- Advanced tool library (WebSearchTool, FetchWebPageTool)

---

[0.6.9]: https://github.com/franck/observ/releases/tag/v0.6.9
[0.6.7]: https://github.com/franck/observ/releases/tag/v0.6.7
[0.6.6]: https://github.com/franck/observ/releases/tag/v0.6.6
[0.6.5]: https://github.com/franck/observ/releases/tag/v0.6.5
[0.6.4]: https://github.com/franck/observ/releases/tag/v0.6.4
[0.6.3]: https://github.com/franck/observ/releases/tag/v0.6.3
[0.6.2]: https://github.com/franck/observ/releases/tag/v0.6.2
[0.6.1]: https://github.com/franck/observ/releases/tag/v0.6.1
[0.6.0]: https://github.com/franck/observ/releases/tag/v0.6.0
[0.5.1]: https://github.com/franck/observ/releases/tag/v0.5.1
[0.5.0]: https://github.com/franck/observ/releases/tag/v0.5.0
[0.4.0]: https://github.com/franck/observ/releases/tag/v0.4.0
[0.3.0]: https://github.com/franck/observ/releases/tag/v0.3.0
[0.1.2]: https://github.com/franck/observ/releases/tag/v0.1.2
[0.1.0]: https://github.com/franck/observ/releases/tag/v0.1.0
[Unreleased]: https://github.com/franck/observ/compare/v0.6.9...HEAD
