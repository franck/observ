# Asset Installation Confirmation Feature

## Summary

Added a confirmation step to the `rails observ:install` generator to validate destination paths before copying asset files, and automatic route mounting to `config/routes.rb`.

## Changes Made

### 1. Updated Install Generator (`lib/generators/observ/install/install_generator.rb`)

#### New Options
```ruby
class_option :force,
             type: :boolean,
             desc: "Skip confirmation prompt",
             default: false

class_option :skip_routes,
             type: :boolean,
             desc: "Skip automatic route mounting",
             default: false
```

#### New `confirm_installation` Method
```ruby
def confirm_installation
  return if options[:force]

  styles_dest = options[:styles_dest] || Observ::AssetInstaller::DEFAULT_STYLES_DEST
  js_dest = options[:js_dest] || Observ::AssetInstaller::DEFAULT_JS_DEST

  say "\n"
  say "=" * 80, :cyan
  say "Observ Asset Installation", :cyan
  say "=" * 80, :cyan
  say "\n"
  say "Assets will be copied to the following locations:", :yellow
  say "  Stylesheets: #{styles_dest}", :yellow
  say "  JavaScript:  #{js_dest}", :yellow
  say "\n"

  unless yes?("Do you want to proceed with the installation? (y/n)", :yellow)
    say "\nInstallation cancelled.", :red
    exit 0
  end
  say "\n"
end
```

**Key Features:**
- Runs before `install_assets` method
- Returns early if `--force` flag is present
- Shows both default and custom destination paths
- Uses Rails' built-in `yes?` helper for user input
- Exits gracefully (exit 0) when user declines
- Color-coded output for better UX

### 2. Updated README.md

Added documentation for:
- Confirmation prompt behavior
- `--force` flag usage
- CI/CD integration examples

### 3. Created Testing Guide

Created `TESTING_INSTALL_GENERATOR.md` with:
- Manual testing scenarios
- Expected behaviors
- Edge cases
- CI/CD integration examples
- Troubleshooting guide

## Usage Examples

### Interactive Installation (Default)
```bash
rails generate observ:install
```

**Output:**
```
================================================================================
Observ Asset Installation
================================================================================

The following changes will be made:

Assets will be copied to:
  Stylesheets: app/javascript/stylesheets/observ
  JavaScript:  app/javascript/controllers/observ

Routes (will be added to config/routes.rb):
  mount Observ::Engine, at: "/observ"

Do you want to proceed with the installation? (y/n)
```

### Non-Interactive Installation (CI/CD)
```bash
rails generate observ:install --force
```
No confirmation prompt - proceeds immediately.

### Custom Destinations with Confirmation
```bash
rails generate observ:install --styles-dest=custom/styles --js-dest=custom/js
```

Shows custom paths in confirmation.

### Custom Destinations without Confirmation
```bash
rails generate observ:install --force --styles-dest=custom/styles
```

### Skip Automatic Route Mounting
```bash
rails generate observ:install --skip-routes
```

Shows custom paths in confirmation but won't modify `config/routes.rb`.

## Benefits

1. **Safety**: Prevents accidental overwrites by showing users exactly where files will be copied
2. **Flexibility**: Supports both interactive and automated workflows
3. **Clarity**: Users can review custom paths before proceeding
4. **CI/CD Ready**: `--force` flag enables automated deployments
5. **User Experience**: Color-coded, well-formatted output

## Implementation Details

### Method Execution Order

Rails generators execute public methods in order:

1. `confirm_installation` - Shows confirmation prompt (unless --force)
2. `install_assets` - Performs the actual installation
3. `show_post_install_message` - Displays success message

### Force Flag Behavior

When `--force` is present:
- `confirm_installation` returns immediately (line 39)
- No user input is requested
- Installation proceeds directly
- Ideal for:
  - CI/CD pipelines
  - Automated scripts
  - Docker builds
  - Deployment automation

### Exit Handling

When user declines installation:
- Uses `exit 0` (not `exit 1`)
- This is correct because user declining is not an error
- Prevents CI/CD pipelines from failing on user choice

### Path Display Logic

The confirmation shows:
- Default paths when no custom options provided
- Custom paths when `--styles-dest` or `--js-dest` specified
- Uses `AssetInstaller::DEFAULT_*` constants for consistency

## Testing

### Automated Verification

A verification script was used during development to ensure:
- ✓ Has --force option
- ✓ Force option defaults to false
- ✓ Has confirm_installation method
- ✓ Checks force flag in confirmation
- ✓ Shows destination paths
- ✓ Prompts user
- ✓ Exits gracefully on decline
- ✓ Uses AssetInstaller constants
- ✓ Displays stylesheets path
- ✓ Displays JavaScript path

### Manual Testing

See `TESTING_INSTALL_GENERATOR.md` for comprehensive manual testing guide.

## Future Enhancements

Potential improvements:
1. Add `--yes` alias for `--force` (common in other tools)
2. Show list of files that will be copied
3. Detect existing files and show what will be overwritten
4. Add `--dry-run` option to preview without copying
5. Support for interactive file-by-file confirmation

## Compatibility

- **Rails**: 7.0+ (as per gem requirements)
- **Ruby**: 3.0+ (as per gem requirements)
- **CI/CD**: Fully compatible with `--force` flag
- **Interactive shells**: Uses standard Rails yes? helper

## Related Files

- `lib/generators/observ/install/install_generator.rb` - Main generator with confirmation
- `lib/observ/asset_installer.rb` - Constants for default paths
- `README.md` - User-facing documentation
- `TESTING_INSTALL_GENERATOR.md` - Testing guide
