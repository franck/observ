# Automatic Route Mounting Feature

## Overview

The `rails generate observ:install` command automatically adds the Observ engine mount to `config/routes.rb` if not already present, streamlining the installation process.

## How It Works

### Default Behavior

When you run `rails generate observ:install`, the generator:

1. **Checks** if `config/routes.rb` contains `mount Observ::Engine`
2. **Shows** in the confirmation prompt whether the route will be added
3. **Adds** the route if not present: `mount Observ::Engine, at: "/observ"`
4. **Skips** if the route already exists (idempotent)

### Route Detection

The generator uses a pattern match to detect existing routes:

```ruby
def route_already_exists?
  routes_file = Rails.root.join("config/routes.rb")
  return false unless routes_file.exist?
  
  routes_content = File.read(routes_file)
  routes_content.match?(/mount\s+Observ::Engine/)
end
```

This detects any variation of:
- `mount Observ::Engine, at: "/observ"`
- `mount Observ::Engine, at: '/observ'`
- `mount Observ::Engine, :at => "/observ"`
- `mount(Observ::Engine, at: "/observ")`

## Usage Examples

### Standard Installation (with route mounting)

```bash
rails generate observ:install
```

**Confirmation shows:**
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

Do you want to proceed with the installation? (y/n) y
```

**Output during installation:**
```
Checking routes...
--------------------------------------------------------------------------------
  ✓ Added route: mount Observ::Engine, at: "/observ"
```

### Skip Route Mounting

If you want to manually configure the route (e.g., different path):

```bash
rails generate observ:install --skip-routes
```

Then manually add to `config/routes.rb`:
```ruby
mount Observ::Engine, at: "/admin/observ"  # Custom path
```

### Route Already Exists

If the route is already in `routes.rb`:

```bash
rails generate observ:install
```

**Output:**
```
Checking routes...
--------------------------------------------------------------------------------
  Engine already mounted in config/routes.rb
```

### Force Installation (no confirmation)

```bash
rails generate observ:install --force
```

Route is added automatically without prompting.

## Where the Route Gets Added

Rails generators use the `route` helper which adds the route at the top of the `Rails.application.routes.draw` block:

**Before:**
```ruby
Rails.application.routes.draw do
  root "home#index"
  resources :posts
end
```

**After:**
```ruby
Rails.application.routes.draw do
  mount Observ::Engine, at: "/observ"
  root "home#index"
  resources :posts
end
```

## Testing the Feature

### Test Case 1: Fresh Rails App

```bash
# Create new Rails app
rails new test_app
cd test_app

# Add observ to Gemfile
echo 'gem "observ", path: "/path/to/observ"' >> Gemfile
bundle install

# Run generator
rails generate observ:install

# Verify route was added
grep "mount Observ::Engine" config/routes.rb
# Should output: mount Observ::Engine, at: "/observ"
```

### Test Case 2: Route Already Exists

```bash
# Run generator again
rails generate observ:install

# Should see: "Engine already mounted in config/routes.rb"
# Verify route is NOT duplicated
grep -c "mount Observ::Engine" config/routes.rb
# Should output: 1
```

### Test Case 3: Skip Routes Flag

```bash
# Remove the route first
sed -i '/mount Observ::Engine/d' config/routes.rb

# Install with --skip-routes
rails generate observ:install --skip-routes --force

# Verify route was NOT added
grep "mount Observ::Engine" config/routes.rb
# Should have no output
```

### Test Case 4: Different Mount Paths

```bash
# Manually add custom mount path
echo 'mount Observ::Engine, at: "/admin/observ"' >> config/routes.rb

# Run generator
rails generate observ:install --force

# Generator should detect existing mount and skip
# Verify only one mount exists
grep -c "mount Observ::Engine" config/routes.rb
# Should output: 1
```

## Benefits

### User Experience
- ✅ **One Less Step** - No need to manually edit routes.rb
- ✅ **Fewer Errors** - Can't forget to mount the engine
- ✅ **Clear Communication** - Confirmation shows exactly what will change
- ✅ **Idempotent** - Can run multiple times safely

### Developer Experience
- ✅ **Follows Rails Conventions** - Uses built-in `route` helper
- ✅ **Flexible** - Can opt-out with `--skip-routes`
- ✅ **Smart Detection** - Won't duplicate existing routes
- ✅ **CI/CD Ready** - Works with `--force` flag

## Edge Cases Handled

### 1. Missing routes.rb

If `config/routes.rb` doesn't exist (unlikely but possible):
```ruby
return false unless routes_file.exist?
```

### 2. Commented Out Route

```ruby
# mount Observ::Engine, at: "/observ"
```

Generator will add a new uncommented route (correct behavior).

### 3. Custom Mount Path Already Exists

```ruby
mount Observ::Engine, at: "/admin/observ"
```

Generator detects and skips (won't add duplicate at `/observ`).

### 4. Routes in Separate Files

Rails 7+ allows:
```ruby
Rails.application.routes.draw do
  draw(:admin)  # Routes from config/routes/admin.rb
end
```

If the mount is in `config/routes/admin.rb`, generator won't detect it and will add to main routes.rb. This is acceptable as having it in the main file is clearer.

## Troubleshooting

### Issue: Route not detected

**Symptom:** Generator adds duplicate route even though one exists.

**Cause:** Unusual spacing or syntax in existing route.

**Solution:** The regex pattern `/mount\s+Observ::Engine/` should catch most cases. If needed, manually remove duplicate.

### Issue: Permission denied

**Symptom:** Error writing to routes.rb.

**Cause:** File permissions or read-only filesystem.

**Solution:** Check file permissions:
```bash
ls -l config/routes.rb
chmod u+w config/routes.rb
```

### Issue: Route added in wrong place

**Symptom:** Route appears in unexpected location.

**Cause:** Malformed routes.rb structure.

**Solution:** Rails' `route` helper adds at the top of the draw block. If routes.rb has unusual structure, manually move the route.

## Customization

### Custom Mount Path

If you want a different path, use `--skip-routes` and manually configure:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Mount at custom path
  mount Observ::Engine, at: "/analytics/observ"
  
  # Or with namespace
  namespace :admin do
    mount Observ::Engine, at: "/observ"
  end
end
```

### Conditional Mounting

For environment-specific mounting:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Only mount in development and staging
  if Rails.env.development? || Rails.env.staging?
    mount Observ::Engine, at: "/observ"
  end
end
```

Use `--skip-routes` and add this manually.

## Implementation Details

### Method Execution Order

1. `confirm_installation` - Shows what will happen (including route)
2. `mount_engine` - Adds route to routes.rb
3. `install_assets` - Copies asset files
4. `show_post_install_message` - Shows success

### Code Reference

**Generator:** `lib/generators/observ/install/install_generator.rb`

**Key methods:**
- `mount_engine` (line ~63) - Adds route
- `route_already_exists?` (line ~107) - Detects existing route
- `confirm_installation` (line ~39) - Shows route in confirmation

## Related Documentation

- `CONFIRMATION_FEATURE.md` - Confirmation prompt behavior
- `TESTING_INSTALL_GENERATOR.md` - Complete testing guide
- `README.md` - User-facing documentation
- `CHANGELOG.md` - Version history

## Future Enhancements

Potential improvements:
1. `--mount-at` option to customize mount path during installation
2. Detect routes in separate files (Rails 7+ draw pattern)
3. Interactive prompt to choose mount path
4. Validation of mount path format
5. Check for path conflicts with existing routes
