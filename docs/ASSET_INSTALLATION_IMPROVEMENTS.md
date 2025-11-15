# Asset Installation Improvements

## Overview

This document describes the improvements made to the Observ gem's asset installation process to address issues with first-time installation.

## Problems Addressed

1. **No automatic asset installation** - Users had to manually run `rails observ:sync_assets` after gem installation
2. **Missing index files** - The sync task copied individual files but didn't create Stimulus controller index files
3. **Poor first-time experience** - No clear guidance or automation for initial setup
4. **Incomplete documentation** - README lacked clear step-by-step instructions for asset setup

## Solution Architecture

Following Ruby best practices, the solution was implemented with:
- Clean service classes that encapsulate business logic
- Thin rake tasks and generators that delegate to services
- Comprehensive RSpec test coverage
- Clear separation of concerns

## New Components

### 1. Service Classes

#### `Observ::AssetSyncer` (lib/observ/asset_syncer.rb)
Handles the low-level file synchronization logic:
- Copies stylesheet files from gem to application
- Copies JavaScript controller files from gem to application
- Compares files to avoid unnecessary copies
- Provides statistics about sync operations
- Supports custom logger injection

**Key Methods:**
- `sync_stylesheets(dest_path)` - Sync SCSS files
- `sync_javascript_controllers(dest_path)` - Sync JS controller files

#### `Observ::IndexFileGenerator` (lib/observ/index_file_generator.rb)
Generates index files for Stimulus controllers:
- Creates `index.js` file that imports all controllers
- Registers controllers with Stimulus application
- Uses `observ--` prefix for namespacing
- Checks if main controllers index imports Observ controllers
- Provides suggestions for manual registration

**Key Methods:**
- `generate_controllers_index(controllers_path)` - Generate index.js
- `check_main_controllers_registration` - Verify registration
- `generate_import_statement(relative_path)` - Create import statement

#### `Observ::AssetInstaller` (lib/observ/asset_installer.rb)
High-level orchestration service:
- Coordinates asset syncing and index generation
- Provides both install and sync operations
- Manages default and custom destination paths
- Logs comprehensive progress and instructions

**Key Methods:**
- `install(styles_dest:, js_dest:, generate_index:)` - Full installation
- `sync(styles_dest:, js_dest:)` - Update-only operation

**Constants:**
- `DEFAULT_STYLES_DEST` = "app/javascript/stylesheets/observ"
- `DEFAULT_JS_DEST` = "app/javascript/controllers/observ"

### 2. Rake Tasks (lib/tasks/observ_tasks.rake)

Simplified rake tasks that delegate to service classes:

#### `rails observ:install_assets[styles_dest,js_dest]`
- Full installation with index file generation
- Accepts optional custom destinations
- Alias: `rails observ:install`

#### `rails observ:sync_assets[styles_dest,js_dest]`
- Update existing files only
- No index file generation
- Alias: `rails observ:sync`

### 3. Generator (lib/generators/observ/install/install_generator.rb)

Rails generator for installation:

```bash
rails generate observ:install
```

**Options:**
- `--styles-dest=PATH` - Custom stylesheet destination
- `--js-dest=PATH` - Custom JavaScript destination
- `--skip-index` - Skip index file generation

**Features:**
- Color-coded output (green for success, yellow for warnings)
- Post-install instructions
- Checks for proper controller registration
- Provides actionable next steps

### 4. Comprehensive Test Coverage

Three complete RSpec test files:

- `spec/lib/observ/asset_syncer_spec.rb` - Tests file synchronization
- `spec/lib/observ/index_file_generator_spec.rb` - Tests index generation
- `spec/lib/observ/asset_installer_spec.rb` - Tests orchestration

**Test Coverage:**
- File copying and synchronization
- Index file generation
- Registration checking
- Custom destinations
- Error handling
- Logging

## Usage Examples

### First-Time Installation

**Recommended (Generator):**
```bash
rails generate observ:install
```

**Alternative (Rake Task):**
```bash
rails observ:install_assets
```

### Custom Destinations

**Generator:**
```bash
rails generate observ:install \
  --styles-dest=app/assets/stylesheets/observ \
  --js-dest=app/javascript/controllers/custom_observ
```

**Rake Task:**
```bash
rails observ:install_assets[app/assets/stylesheets/observ,app/javascript/controllers/custom]
```

### Updating After Gem Upgrade

```bash
rails observ:sync_assets
```

### Programmatic Usage

```ruby
require 'observ/asset_installer'

installer = Observ::AssetInstaller.new(
  gem_root: Observ::Engine.root,
  app_root: Rails.root
)

result = installer.install(
  styles_dest: 'app/javascript/stylesheets/observ',
  js_dest: 'app/javascript/controllers/observ',
  generate_index: true
)

# Check results
puts "Copied #{result[:styles][:files_copied]} stylesheets"
puts "Copied #{result[:javascript][:files_copied]} controllers"
puts "Index created: #{result[:index][:created]}"
puts "Registration required: #{!result[:registration][:registered]}"
```

## File Structure

```
observ/
├── lib/
│   ├── observ/
│   │   ├── asset_installer.rb       # Main orchestration service
│   │   ├── asset_syncer.rb          # File synchronization logic
│   │   ├── index_file_generator.rb  # Index file generation
│   │   └── ...
│   ├── generators/
│   │   └── observ/
│   │       └── install/
│   │           ├── install_generator.rb
│   │           ├── USAGE
│   │           └── templates/
│   └── tasks/
│       └── observ_tasks.rake        # Simplified rake tasks
└── spec/
    └── lib/
        └── observ/
            ├── asset_installer_spec.rb
            ├── asset_syncer_spec.rb
            └── index_file_generator_spec.rb
```

## Documentation Updates

### README.md Changes

1. **Installation Section**: Added clear asset installation instructions
2. **Asset Management Section**: New dedicated section with:
   - Generator usage examples
   - Rake task examples
   - Programmatic API documentation
3. **Troubleshooting Section**: Enhanced "Assets not loading" with:
   - Step-by-step resolution
   - Different asset pipeline configurations
   - Verification steps
   - Sync instructions for gem updates

## Benefits

1. **Better First-Time Experience**: New users get a guided installation with clear next steps
2. **Flexibility**: Supports custom destinations for different project structures
3. **Maintainability**: Logic in testable service classes, not in rake tasks or generators
4. **Clarity**: Comprehensive logging and error messages guide users
5. **Automation**: Index files are generated automatically
6. **Safety**: File comparison prevents unnecessary overwrites
7. **Testability**: Full RSpec coverage ensures reliability

## Design Principles Followed

1. **Single Responsibility**: Each service class has one clear purpose
2. **Dependency Injection**: Logger and paths are injected for flexibility
3. **Separation of Concerns**: UI (rake/generator) separated from business logic (services)
4. **Don't Repeat Yourself**: Shared logic in service classes
5. **Test Coverage**: Comprehensive specs for all new code
6. **Clear Documentation**: README, inline comments, and this summary

## Migration Path

For existing users:
- `rails observ:sync_assets` still works as before
- New `rails observ:install_assets` provides better first-time experience
- No breaking changes to existing functionality

## Future Enhancements

Potential future improvements:
1. Auto-detect asset pipeline type (Sprockets vs Vite/esbuild)
2. Automatically add import statements to application files
3. Support for more asset types (images, fonts)
4. Rollback functionality
5. Dry-run mode to preview changes
6. CI/CD integration helpers
