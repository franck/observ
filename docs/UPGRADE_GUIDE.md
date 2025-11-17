# Upgrade Guide

## Asset Installation Changes

Starting from version 0.1.2, Observ provides improved asset installation with automatic index file generation and better first-time user experience.

### What's New

1. **New Install Generator**: `rails generate observ:install`
2. **New Rake Task**: `rails observ:install_assets` (with index generation)
3. **Automatic Index Files**: Stimulus controller index files are created automatically
4. **Better Documentation**: Clearer instructions in README

### For New Users

If you're installing Observ for the first time, use the new installation method:

```bash
# Run migrations
rails observ:install:migrations
rails db:migrate

# Install assets (NEW!)
rails generate observ:install
```

This will:
- Copy all stylesheets to `app/javascript/stylesheets/observ`
- Copy all controllers to `app/javascript/controllers/observ`
- Generate `app/javascript/controllers/observ/index.js` with all imports
- Check if controllers are registered in your main app

### For Existing Users

If you're already using Observ, nothing breaks! Your existing workflow continues to work:

```bash
# This still works exactly as before
rails observ:sync_assets
```

However, you can benefit from the new features:

```bash
# Use the new install task to generate index files
rails observ:install_assets

# Or use the generator
rails generate observ:install
```

### Migration Steps (Optional)

If you want to take advantage of the new automatic index file generation:

1. **Back up your current index file** (if you have custom modifications):
   ```bash
   cp app/javascript/controllers/observ/index.js app/javascript/controllers/observ/index.js.backup
   ```

2. **Run the new install task**:
   ```bash
   rails observ:install_assets
   ```

3. **Compare the generated file** with your backup:
   ```bash
   diff app/javascript/controllers/observ/index.js.backup app/javascript/controllers/observ/index.js
   ```

4. **Merge any custom changes** if needed

### What Changed Under the Hood

The asset management code has been refactored into clean service classes:

- **`Observ::AssetSyncer`**: Handles file synchronization
- **`Observ::IndexFileGenerator`**: Generates controller index files
- **`Observ::AssetInstaller`**: Orchestrates the installation process

The rake tasks and generators are now thin wrappers around these services, making the codebase more maintainable and testable.

### Rake Task Comparison

| Old Task | New Task | Purpose |
|----------|----------|---------|
| `observ:sync_assets` | `observ:sync_assets` | Update files only (no index generation) |
| N/A | `observ:install_assets` | Full install with index generation |
| `observ:sync` (alias) | `observ:sync` (alias) | Shorthand for sync |
| N/A | `observ:install` (alias) | Shorthand for install |

### Troubleshooting

#### Controllers not working after upgrade

If your Stimulus controllers stop working after updating:

1. Check browser console for errors
2. Verify `app/javascript/controllers/index.js` imports observ:
   ```javascript
   import './observ'
   ```
3. Verify `app/javascript/controllers/observ/index.js` exists and has proper imports
4. Clear your browser cache and restart your dev server

#### Index file conflicts

If you've customized your index file and the generator overwrites it:

1. Restore from backup
2. Run `rails generate observ:install --skip-index` to avoid regeneration
3. Manually add any new controllers to your custom index

### Getting Help

- Check the [README](README.md) for detailed installation instructions
- See [ASSET_INSTALLATION_IMPROVEMENTS.md](ASSET_INSTALLATION_IMPROVEMENTS.md) for technical details
- Report issues on GitHub

## Breaking Changes

**None!** This release is fully backward compatible. All existing functionality continues to work as before.

## Deprecations

**None at this time.** We may deprecate some older patterns in future major versions, but you'll receive plenty of warning.

## Recommendations

- New projects: Use `rails generate observ:install`
- Existing projects: Continue using `rails observ:sync_assets` or upgrade to `rails observ:install_assets` at your convenience
- CI/CD: Consider using `rails observ:sync_assets` to avoid regenerating index files unnecessarily
