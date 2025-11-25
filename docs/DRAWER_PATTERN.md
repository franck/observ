# Drawer Pattern Documentation

This document explains how to implement drawer-based UI components in the Observ gem using Turbo Streams and Stimulus.

## Overview

The drawer pattern provides a slide-in panel for displaying contextual information or forms without navigating away from the current page. It uses:

- **Stimulus** for JavaScript behavior (opening/closing, loading content)
- **Turbo Streams** for dynamically updating drawer content via AJAX
- **Rails routes and controllers** for serving drawer content

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Page with Drawer Trigger Button                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Button with data-action="click->observ--drawer#open"   │   │
│  │  and data-drawer-url-param="/path/to/drawer"            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Drawer Controller (Stimulus)                           │   │
│  │  - Opens drawer panel                                   │   │
│  │  - Fetches content via fetch() with turbo-stream header │   │
│  │  - Injects turbo-stream response into DOM               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Turbo Stream Response                                  │   │
│  │  - Updates #drawer-header-title                         │   │
│  │  - Updates #drawer-content                              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Drawer Partial (`app/views/shared/_drawer.html.erb`)

The drawer partial provides the HTML structure. It must be included in the layout.

```erb
<div class="observ-drawer" data-observ--drawer-target="drawer">
  <div class="observ-drawer__overlay" data-action="click->observ--drawer#close"></div>
  
  <div class="observ-drawer__panel">
    <div class="observ-drawer__header">
      <button 
        type="button" 
        class="observ-drawer__close-btn" 
        data-action="click->observ--drawer#close"
        aria-label="Close drawer">
        <!-- Close icon SVG -->
      </button>
      <h2 id="drawer-header-title" class="observ-drawer__title" data-observ--drawer-target="headerTitle">
        Loading...
      </h2>
    </div>
    
    <div id="drawer-content" class="observ-drawer__content" data-observ--drawer-target="content">
      <div class="observ-drawer__loading">
        <span class="observ-spinner"></span>
      </div>
    </div>
  </div>
</div>
```

**Important:** The elements must have both:
- `id` attributes (`drawer-header-title`, `drawer-content`) for Turbo Stream targeting
- `data-observ--drawer-target` attributes for Stimulus controller access

### 2. Stimulus Controller (`app/assets/javascripts/observ/controllers/drawer_controller.js`)

The drawer controller handles:
- Opening the drawer and showing loading state
- Fetching content from the server with Turbo Stream headers
- Closing the drawer

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "content", "headerTitle"]

  open(event) {
    event.preventDefault()
    const url = event.currentTarget.dataset.drawerUrlParam

    if (!url) {
      console.error("No URL provided for drawer")
      return
    }

    this.drawerTarget.classList.add("open")
    this.replaceSpinners()
    this.fetchContent(url)
  }

  close(event) {
    if (event) event.preventDefault()
    this.drawerTarget.classList.remove("open")
  }

  replaceSpinners() {
    this.headerTitleTarget.innerHTML = '<span class="observ-spinner"></span>'
    this.contentTarget.innerHTML = '<div class="observ-drawer__loading"><span class="observ-spinner"></span></div>'
  }

  async fetchContent(url) {
    try {
      const response = await fetch(url, {
        headers: {
          Accept: "text/vnd.turbo-stream.html"
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const html = await response.text()
      const turboStream = document.createElement("div")
      turboStream.innerHTML = html
      document.body.appendChild(turboStream)
      setTimeout(() => turboStream.remove(), 100)
    } catch (error) {
      console.error("Failed to fetch drawer content:", error)
      this.contentTarget.innerHTML = '<div class="observ-drawer__error">Failed to load content</div>'
    }
  }
}
```

### 3. Trigger Button

Add a button/link that opens the drawer:

```erb
<%= link_to "#", 
    class: "observ-button observ-button--secondary observ-button--sm",
    data: { 
      action: "click->observ--drawer#open", 
      drawer_url_param: my_drawer_path(@resource)
    } do %>
  Open Drawer
<% end %>
```

**Required data attributes:**
- `data-action="click->observ--drawer#open"` - triggers the drawer open action
- `data-drawer-url-param` - the URL to fetch drawer content from

### 4. Route

Add a route for the drawer endpoint:

```ruby
# config/routes.rb
resources :traces, only: [:index, :show] do
  member do
    get :my_drawer  # => /traces/:id/my_drawer
  end
end
```

### 5. Controller Action

Add a controller action that sets up instance variables:

```ruby
# app/controllers/observ/traces_controller.rb
def my_drawer
  @trace = Observ::Trace.find(params[:id])
  @related_data = SomeModel.all
  # No explicit render needed - Rails will find the turbo_stream template
end
```

### 6. Turbo Stream Template

Create a `.turbo_stream.erb` template that updates the drawer:

```erb
<%# app/views/observ/traces/my_drawer.turbo_stream.erb %>

<%= turbo_stream.update "drawer-header-title" do %>
  My Drawer Title
<% end %>

<%= turbo_stream.update "drawer-content" do %>
  <div class="observ-drawer__section">
    <!-- Your drawer content here -->
    <p>Content for <%= @trace.name %></p>
    
    <!-- Forms work normally -->
    <%= form_with url: some_path, method: :post, class: "observ-form" do |f| %>
      <!-- form fields -->
      
      <div class="observ-form__actions">
        <%= f.submit "Submit", class: "observ-button observ-button--primary" %>
        <button type="button" class="observ-button" data-action="click->observ--drawer#close">
          Cancel
        </button>
      </div>
    <% end %>
  </div>
<% end %>
```

## Existing Drawer Examples

The Observ gem includes several drawer implementations:

| Drawer | Route | Purpose |
|--------|-------|---------|
| `annotations_drawer` | `GET /traces/:id/annotations_drawer` | Add/view annotations on traces |
| `text_output_drawer` | `GET /traces/:id/text_output_drawer` | View formatted trace text output |
| `add_to_dataset_drawer` | `GET /traces/:id/add_to_dataset_drawer` | Add trace to a dataset |
| `annotations_drawer` | `GET /sessions/:id/annotations_drawer` | Add/view annotations on sessions |

## Testing Drawers

When testing drawer endpoints, use the Turbo Stream Accept header:

```ruby
# spec/requests/observ/traces_controller_spec.rb
describe "GET /observ/traces/:id/my_drawer" do
  let(:turbo_stream_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  it "returns success" do
    get my_drawer_observ_trace_path(trace), headers: turbo_stream_headers
    expect(response).to have_http_status(:success)
  end

  it "displays expected content" do
    get my_drawer_observ_trace_path(trace), headers: turbo_stream_headers
    expect(response.body).to include("expected content")
  end
end
```

**Note:** The test environment requires `turbo-rails` gem to be loaded for proper MIME type handling.

## CSS Classes

The drawer uses these CSS classes (defined in `app/assets/stylesheets/observ/`):

| Class | Purpose |
|-------|---------|
| `.observ-drawer` | Main drawer container |
| `.observ-drawer.open` | Drawer in open state |
| `.observ-drawer__overlay` | Semi-transparent backdrop |
| `.observ-drawer__panel` | The slide-in panel |
| `.observ-drawer__header` | Header with title and close button |
| `.observ-drawer__title` | Title element |
| `.observ-drawer__content` | Main content area |
| `.observ-drawer__section` | Content section wrapper |
| `.observ-drawer__loading` | Loading state container |
| `.observ-drawer__error` | Error state container |

## Common Patterns

### Form in Drawer

```erb
<%= turbo_stream.update "drawer-content" do %>
  <div class="observ-drawer__section">
    <%= form_with url: submit_path, method: :post, class: "observ-form" do |f| %>
      <div class="observ-form__group">
        <%= f.label :field, class: "observ-form__label" %>
        <%= f.text_field :field, class: "observ-form__input" %>
      </div>
      
      <div class="observ-form__actions">
        <%= f.submit "Save", class: "observ-button observ-button--primary" %>
        <button type="button" class="observ-button" data-action="click->observ--drawer#close">
          Cancel
        </button>
      </div>
    <% end %>
  </div>
<% end %>
```

### Empty State

```erb
<%= turbo_stream.update "drawer-content" do %>
  <div class="observ-drawer__section">
    <% if @items.any? %>
      <!-- content -->
    <% else %>
      <div class="observ-card__empty">
        <p class="observ-card__empty-text">No items found</p>
        <p class="observ-card__empty-subtext">Create an item first.</p>
        <%= link_to "Create Item", new_item_path, class: "observ-button observ-button--primary" %>
      </div>
    <% end %>
  </div>
<% end %>
```

### Multiple Sections

```erb
<%= turbo_stream.update "drawer-content" do %>
  <div class="observ-drawer__section">
    <h3 class="observ-drawer__section-title">Section 1</h3>
    <!-- section 1 content -->
  </div>
  
  <div class="observ-drawer__section">
    <h3 class="observ-drawer__section-title">Section 2</h3>
    <!-- section 2 content -->
  </div>
<% end %>
```

## Troubleshooting

### Drawer loads indefinitely

**Cause:** The turbo stream targets (`drawer-header-title`, `drawer-content`) don't have matching `id` attributes in the DOM.

**Solution:** Ensure the drawer partial has `id` attributes on the target elements:
```erb
<h2 id="drawer-header-title" ...>
<div id="drawer-content" ...>
```

### 406 Not Acceptable response

**Cause:** Rails doesn't recognize the `text/vnd.turbo-stream.html` MIME type.

**Solution:** Ensure `turbo-rails` gem is loaded in the application.

### Route not found

**Cause:** Engine routes not reloaded after adding new routes.

**Solution:** Restart the Rails server to pick up new engine routes.

### Content not updating

**Cause:** JavaScript error or incorrect Stimulus controller connection.

**Solution:** Check browser console for errors. Ensure the drawer controller is properly connected with `data-controller="observ--drawer"` on a parent element.
