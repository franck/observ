# Testing the Install Generator

This guide explains how to manually test the `observ:install` generator with confirmation prompts.

## Prerequisites

Ensure you're working in a Rails application that has the Observ gem installed.

## Test Scenarios

### 1. Default Installation with Confirmation

Test that the generator prompts for confirmation before installing assets:

```bash
cd /path/to/parent/rails/app
rails generate observ:install
```

**Expected Output:**
```
================================================================================
Observ Asset Installation
================================================================================

Assets will be copied to the following locations:
  Stylesheets: app/javascript/stylesheets/observ
  JavaScript:  app/javascript/controllers/observ

Do you want to proceed with the installation? (y/n) y

================================================================================
Observ Asset Installation
================================================================================

Gem location: /path/to/observ
App location: /path/to/app

Destinations:
  Styles: app/javascript/stylesheets/observ
  JavaScript: app/javascript/controllers/observ

Syncing Observ stylesheets...
--------------------------------------------------------------------------------
  Copied _annotations.scss
  Copied _base.scss
  ...
  
================================================================================
Observ assets installed successfully!
================================================================================

Next steps:
  1. Import stylesheets in your application
  ...
```

**Expected Behavior:**
- Generator displays a header with "Observ Asset Installation"
- Shows "The following changes will be made:"
- Shows destination paths in yellow
- Shows route mounting info (if route doesn't exist)
- Prompts: "Do you want to proceed with the installation? (y/n)"
- If you answer "y": Installation proceeds normally (route is added)
- If you answer "n": Shows "Installation cancelled." in red and exits

### 2. Installation with Custom Destinations

Test confirmation with custom paths:

```bash
rails generate observ:install --styles-dest=custom/styles --js-dest=custom/js
```

**Expected Behavior:**
- Generator displays custom destination paths:
  - Stylesheets: `custom/styles`
  - JavaScript: `custom/js`
- Prompts for confirmation
- Installation proceeds to custom locations if confirmed

### 3. Force Installation (Skip Confirmation)

Test that `--force` flag skips the confirmation:

```bash
rails generate observ:install --force
```

**Expected Behavior:**
- No confirmation prompt appears
- Installation proceeds immediately to default locations
- All assets are copied without user interaction

### 4. Force Installation with Custom Destinations

Test `--force` with custom paths:

```bash
rails generate observ:install --force --styles-dest=custom/styles --js-dest=custom/js
```

**Expected Behavior:**
- No confirmation prompt appears
- Installation proceeds immediately to custom locations
- Useful for CI/CD pipelines and automated scripts

### 5. Installation with Skip Index

Test confirmation with `--skip-index` option:

```bash
rails generate observ:install --skip-index
```

**Expected Behavior:**
- Confirmation prompt shows destinations
- If confirmed, assets are copied but index files are not generated
- Route is still added (unless --skip-routes)
- Post-install message still appears

### 6. Installation with Skip Routes

Test skipping automatic route mounting:

```bash
rails generate observ:install --skip-routes
```

**Expected Behavior:**
- Confirmation prompt does NOT show route info
- Assets are copied normally
- Route is NOT added to config/routes.rb
- Must manually add route later

### 7. Route Already Exists

Test when route is already in routes.rb:

```bash
# First installation
rails generate observ:install --force

# Second installation
rails generate observ:install
```

**Expected Behavior:**
- Confirmation shows "Engine already mounted in config/routes.rb"
- Installation proceeds
- Route is NOT duplicated
- Only one mount line in routes.rb

## Verification Steps

After each test scenario, verify:

1. **Files are copied correctly:**
   ```bash
   ls -la app/javascript/stylesheets/observ/
   ls -la app/javascript/controllers/observ/
   ```

2. **Index files are generated (unless --skip-index):**
   ```bash
   cat app/javascript/controllers/observ/index.js
   ```

3. **Route is added to config/routes.rb (unless --skip-routes):**
   ```bash
   grep "mount Observ::Engine" config/routes.rb
   ```

4. **No errors in console output**

5. **Post-install message appears** with next steps

## Edge Cases to Test

### Cancel During Prompt

1. Run: `rails generate observ:install`
2. When prompted, enter "n" or "no"
3. Verify that:
   - Message "Installation cancelled." appears
   - No files are copied
   - Generator exits cleanly (exit code 0)

### Invalid Input Handling

Rails generators typically handle yes/no prompts gracefully. Test with:
- Empty input (should reprompt or use default)
- Invalid answers like "maybe" (should reprompt)

### CI/CD Environment

Test in a non-interactive environment:

```bash
# This should work without hanging
echo "y" | rails generate observ:install

# Or better, use --force
rails generate observ:install --force
```

## Code Review Checklist

When reviewing the implementation:

- [ ] `confirm_installation` method runs before `install_assets`
- [ ] Method returns early if `--force` flag is present
- [ ] Default destinations are pulled from `AssetInstaller` constants
- [ ] Custom destinations from options are displayed correctly
- [ ] `exit 0` is called when user declines (not `exit 1` or error)
- [ ] README.md documents the `--force` flag
- [ ] Example commands show both confirmation and force modes
- [ ] Help text (`rails generate observ:install --help`) shows all options

## Automated Testing Notes

While full generator tests require a complex Rails test environment setup, you can verify the logic with:

1. **Unit tests** for the confirmation logic (mock yes? method)
2. **Integration tests** in the parent Rails app's test suite
3. **Manual smoke testing** as described above

## Common Issues and Troubleshooting

### Issue: Generator doesn't prompt

**Cause:** `--force` flag may be set by default somewhere
**Solution:** Check `options[:force]` value, ensure it defaults to `false`

### Issue: Exits with error when user declines

**Cause:** Using `exit 1` instead of `exit 0`
**Solution:** User declining is not an error, use `exit 0`

### Issue: Paths not showing correctly

**Cause:** Options not being read correctly
**Solution:** Verify `options[:styles_dest]` and `options[:js_dest]` are accessible

### Issue: Confirmation bypassed unexpectedly

**Cause:** `yes?` method may be stubbed in tests
**Solution:** Ensure tests mock appropriately, don't affect production code

## Integration with CI/CD

For automated deployments, always use `--force`:

```yaml
# Example GitHub Actions
- name: Install Observ assets
  run: rails generate observ:install --force

# Example GitLab CI
script:
  - bundle exec rails generate observ:install --force
```

This ensures the pipeline doesn't hang waiting for user input.
