# Drawer Partial Fix

## Issue

When running `rails generate observ:install` in a fresh Rails application and visiting `/observ`, the application would crash with:

```
ActionView::Template::Error (Missing partial shared/_drawer with {locale: [:en], formats: [:html], variants: [], handlers: [:raw, :erb, :html, :builder, :ruby, :jbuilder]}.
```

## Root Cause

The Observ engine's main layout (`app/views/layouts/observ/application.html.erb`) includes this line:

```erb
<%= render "shared/drawer" %>
```

However, the partial `app/views/shared/_drawer.html.erb` was missing from the engine. This was likely an oversight during the engine extraction process.

The `app/views/shared/` directory existed but was empty, causing Rails to look for the partial in the host application's view directory instead of the engine's.

## Solution

Created the missing partial at `app/views/shared/_drawer.html.erb` with the correct HTML structure.

### Drawer Structure

The drawer partial implements a slide-out panel component with three Stimulus targets that match the drawer controller:

```erb
<div class="observ-drawer" data-observ--drawer-target="drawer">
  <!-- Overlay (clickable background to close) -->
  <div class="observ-drawer__overlay" data-action="click->observ--drawer#close"></div>
  
  <!-- Panel (slides in from right) -->
  <div class="observ-drawer__panel">
    <!-- Header with close button and title -->
    <div class="observ-drawer__header">
      <button data-action="click->observ--drawer#close">Close</button>
      <h2 data-observ--drawer-target="headerTitle">Loading...</h2>
    </div>
    
    <!-- Content area (loaded dynamically via Turbo Streams) -->
    <div data-observ--drawer-target="content">
      <div class="observ-drawer__loading">
        <span class="observ-spinner"></span>
      </div>
    </div>
  </div>
</div>
```

### Stimulus Controller Targets

The drawer controller (`app/assets/javascripts/observ/controllers/drawer_controller.js`) defines three targets:

1. **drawer** - Main container element
2. **headerTitle** - Title that gets replaced when content loads
3. **content** - Content area that gets populated via fetch

### Usage

The drawer is used throughout the Observ UI for displaying:

- Annotation details
- Trace text output
- Session information
- Other slide-out content

Example usage from a view:

```erb
<%= link_to "View Annotations",
  annotations_drawer_session_path(@session),
  class: "observ-button",
  data: { 
    action: "click->observ--drawer#open", 
    drawer_url_param: annotations_drawer_session_path(@session)
  } %>
```

When clicked, this:
1. Opens the drawer (adds `open` class)
2. Shows loading spinner
3. Fetches content from URL via Turbo Stream
4. Replaces loading content with fetched content

## Files Modified

- **Created:** `app/views/shared/_drawer.html.erb`

## Testing

After creating the partial:

1. ✅ Fresh installation no longer crashes
2. ✅ `/observ` route loads successfully
3. ✅ Drawer opens when clicking annotation buttons
4. ✅ Drawer closes when clicking overlay or close button
5. ✅ Content loads dynamically via Turbo Streams

## Prevention

To prevent this issue in the future:

1. **During extraction:** Ensure all partial references in layouts/views have corresponding files
2. **CI/CD:** Add smoke test that visits all main routes after fresh install
3. **Documentation:** Keep extraction checklist for tracking all required files

## Related Files

- **Layout:** `app/views/layouts/observ/application.html.erb:79`
- **Controller:** `app/assets/javascripts/observ/controllers/drawer_controller.js`
- **Styles:** `app/assets/stylesheets/observ/_drawer.scss`
- **Usage Examples:**
  - `app/views/observ/sessions/show.html.erb`
  - `app/views/observ/traces/show.html.erb`

## Alternative Solutions Considered

### Option 1: Namespace the Partial (Recommended for Future)

Instead of `render "shared/drawer"`, use:

```erb
<%= render "observ/shared/drawer" %>
```

Then move to: `app/views/observ/shared/_drawer.html.erb`

**Pros:**
- More explicit namespacing
- Follows Rails engine conventions
- No confusion with host app partials

**Cons:**
- Requires refactoring existing reference

### Option 2: Copy to Host App

Document that users need to copy the partial to their app.

**Pros:**
- Allows customization

**Cons:**
- Extra installation step
- Defeats purpose of engine encapsulation
- Not recommended

## Conclusion

The missing drawer partial has been restored. Fresh installations of Observ 0.2.0+ will work without this error.
