# Observ UI Styleguide

This document provides comprehensive guidelines for styling the Observ application. All components use a consistent dark theme inspired by Better Stack's UI.

## Table of Contents

1. [Design Principles](#design-principles)
2. [Color System](#color-system)
3. [Typography](#typography)
4. [Spacing](#spacing)
5. [Layout](#layout)
6. [Components](#components)
7. [Helpers](#helpers)
8. [Best Practices](#best-practices)

---

## Design Principles

1. **Dark-first**: The UI uses a deep navy dark theme as the default
2. **Subtle interactions**: Hover effects use border highlights rather than background changes
3. **Consistent spacing**: Use spacing variables for all margins and padding
4. **Semantic colors**: Use purpose-based color variables, not raw hex values
5. **Scoped styles**: All styles are scoped within `.observ-layout` to avoid conflicts

---

## Color System

### Brand & Accent Colors

| Variable | Hex | Usage |
|----------|-----|-------|
| `$observ-primary` | `#3b82f6` | Primary actions, links, active states |
| `$observ-success` | `#10b981` | Success states, positive indicators |
| `$observ-warning` | `#f59e0b` | Warnings, caution states |
| `$observ-danger` | `#ef4444` | Errors, destructive actions |
| `$observ-info` | `#06b6d4` | Informational elements |
| `$observ-purple` | `#a78bfa` | AI/special features accent |

### Background Colors

| Variable | Hex | Usage |
|----------|-----|-------|
| `$observ-bg-page` | `#0d0d1a` | Page background (darkest) |
| `$observ-bg-surface` | `#1a1a2e` | Cards, sidebar, surfaces |
| `$observ-bg-elevated` | `#252540` | Dropdowns, modals, inputs |
| `$observ-bg-hover` | `#2a2a45` | Hover states |

### Border Colors

| Variable | Hex | Usage |
|----------|-----|-------|
| `$observ-border-color` | `#2a2a40` | Standard borders |
| `$observ-border-subtle` | `#1f1f35` | Subtle dividers |
| `$observ-border-strong` | `#3a3a55` | Emphasized borders, hover states |

### Text Colors

| Variable | Hex | Usage |
|----------|-----|-------|
| `$observ-text-primary` | `#f3f4f6` | Primary text, headings |
| `$observ-text-secondary` | `#9ca3af` | Secondary text, labels |
| `$observ-text-muted` | `#6b7280` | Muted text, placeholders |

### Special Colors

| Variable | Hex | Usage |
|----------|-----|-------|
| `$observ-white` | `#ffffff` | Text on colored backgrounds |
| `$observ-syntax-number` | `#ff9800` | JSON/code number values |
| `$observ-syntax-boolean` | `#c792ea` | JSON/code boolean values |

---

## Typography

### Font Families

```scss
$observ-font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
$observ-font-family-mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
```

### Font Sizes

| Variable | Size | Usage |
|----------|------|-------|
| `$observ-font-size-xs` | `0.75rem` (12px) | Badges, timestamps, labels |
| `$observ-font-size-sm` | `0.875rem` (14px) | Body text, table cells |
| `$observ-font-size-base` | `1rem` (16px) | Default body text |
| `$observ-font-size-lg` | `1.125rem` (18px) | Sidebar brand, card titles |
| `$observ-font-size-xl` | `1.25rem` (20px) | Section headings |
| `$observ-font-size-2xl` | `1.5rem` (24px) | Page titles |
| `$observ-font-size-3xl` | `1.875rem` (30px) | Large stat values |

---

## Spacing

Use these spacing variables consistently:

| Variable | Size | Usage |
|----------|------|-------|
| `$observ-spacing-xs` | `0.25rem` (4px) | Tight gaps, inline spacing |
| `$observ-spacing-sm` | `0.5rem` (8px) | Button padding, small gaps |
| `$observ-spacing-md` | `1rem` (16px) | Card padding, form fields |
| `$observ-spacing-lg` | `1.5rem` (24px) | Section spacing, card body |
| `$observ-spacing-xl` | `2rem` (32px) | Page padding, large gaps |
| `$observ-spacing-2xl` | `3rem` (48px) | Empty states, hero spacing |

### Border Radius

| Variable | Size | Usage |
|----------|------|-------|
| `$observ-border-radius-sm` | `0.25rem` | Buttons, inputs, badges |
| `$observ-border-radius` | `0.5rem` | Cards, modals |
| `$observ-border-radius-lg` | `0.75rem` | Large cards |

---

## Layout

### Page Structure

```erb
<body class="observ-layout">
  <aside class="observ-sidebar">
    <!-- Sidebar navigation -->
  </aside>
  
  <div class="observ-main-wrapper">
    <main class="observ-main">
      <!-- Page content -->
    </main>
    
    <footer class="observ-footer">
      <!-- Footer -->
    </footer>
  </div>
</body>
```

### Page Content Structure

```erb
<div class="observ-page">
  <div class="observ-page__header">
    <h1 class="observ-page__title">Page Title</h1>
    <div class="observ-page__actions">
      <!-- Action buttons -->
    </div>
  </div>
  
  <div class="observ-page__content">
    <!-- Main content with automatic vertical spacing -->
  </div>
</div>
```

### Grid System

```erb
<%# 2-column grid %>
<div class="observ-grid observ-grid--2">
  <div class="observ-card">...</div>
  <div class="observ-card">...</div>
</div>

<%# 3-column grid %>
<div class="observ-grid observ-grid--3">...</div>

<%# 4-column grid %>
<div class="observ-grid observ-grid--4">...</div>
```

---

## Components

### Cards

Basic card structure:

```erb
<div class="observ-card">
  <div class="observ-card__header">
    <h3 class="observ-card__title">Card Title</h3>
    <div class="observ-card__actions">
      <!-- Optional action buttons -->
    </div>
  </div>
  <div class="observ-card__body">
    <!-- Card content -->
  </div>
  <div class="observ-card__footer">
    <!-- Optional footer -->
  </div>
</div>
```

Modifiers:
- `observ-card--span-2`: Span 2 columns in a grid
- `observ-card--highlighted`: Add primary border highlight

### Buttons

```erb
<%# Primary button (main actions) %>
<%= link_to "Save", path, class: "observ-button observ-button--primary" %>

<%# Secondary button (default) %>
<%= link_to "Cancel", path, class: "observ-button observ-button--secondary" %>

<%# Danger button %>
<%= link_to "Delete", path, class: "observ-button observ-button--danger" %>

<%# Small button %>
<%= link_to "Edit", path, class: "observ-button observ-button--sm" %>

<%# Block button (full width) %>
<%= link_to "Submit", path, class: "observ-button observ-button--primary observ-button--block" %>
```

### Badges

```erb
<span class="observ-badge observ-badge--success">Active</span>
<span class="observ-badge observ-badge--danger">Error</span>
<span class="observ-badge observ-badge--warning">Pending</span>
<span class="observ-badge observ-badge--info">Info</span>
<span class="observ-badge observ-badge--secondary">Default</span>
<span class="observ-badge observ-badge--generation">AI</span>
```

### Tables

```erb
<table class="observ-table">
  <thead class="observ-table__header">
    <tr class="observ-table__row">
      <th class="observ-table__cell">Column 1</th>
      <th class="observ-table__cell">Column 2</th>
      <th class="observ-table__cell observ-table__cell--numeric">Amount</th>
      <th class="observ-table__cell observ-table__cell--actions"></th>
    </tr>
  </thead>
  <tbody>
    <tr class="observ-table__row">
      <td class="observ-table__cell">Value 1</td>
      <td class="observ-table__cell">Value 2</td>
      <td class="observ-table__cell observ-table__cell--numeric">123</td>
      <td class="observ-table__cell observ-table__cell--actions">
        <%= link_to "View", path, class: "observ-button observ-button--sm" %>
      </td>
    </tr>
  </tbody>
</table>
```

Modifiers:
- `observ-table--compact`: Reduced padding

### Forms

```erb
<%= form_with model: @model, class: "observ-form" do |f| %>
  <div class="observ-form__group">
    <%= f.label :name, class: "observ-form__label" %>
    <%= f.text_field :name, class: "observ-form__input" %>
    <p class="observ-form__hint">Helper text goes here</p>
  </div>
  
  <div class="observ-form__group">
    <%= f.label :description, class: "observ-form__label" %>
    <%= f.text_area :description, class: "observ-form__textarea" %>
  </div>
  
  <div class="observ-form__group">
    <%= f.label :status, class: "observ-form__label" %>
    <%= f.select :status, options, {}, class: "observ-form__select" %>
  </div>
  
  <div class="observ-form__actions">
    <%= f.submit "Save", class: "observ-button observ-button--primary" %>
    <%= link_to "Cancel", back_path, class: "observ-button observ-button--secondary" %>
  </div>
<% end %>
```

### Alerts

```erb
<div class="observ-alert observ-alert--success">
  Success message here
</div>

<div class="observ-alert observ-alert--danger">
  Error message here
</div>

<div class="observ-alert observ-alert--warning">
  Warning message here
</div>

<div class="observ-alert observ-alert--info">
  Info message here
</div>
```

### Tabs

```erb
<div class="observ-tabs">
  <%= link_to "Tab 1", path1, class: "observ-tab observ-tab--active" %>
  <%= link_to "Tab 2", path2, class: "observ-tab" %>
  <%= link_to "Tab 3", path3, class: "observ-tab" %>
</div>
```

### Empty State

```erb
<div class="observ-empty-state">
  <p class="observ-empty-state__text">No items found</p>
  <p class="observ-empty-state__subtext">
    Create your first item to get started.
  </p>
</div>
```

### Stat List

For displaying key-value pairs:

```erb
<div class="observ-stat-list">
  <div class="observ-stat-list__item">
    <span class="observ-stat-list__label">Label</span>
    <span class="observ-stat-list__value">Value</span>
  </div>
</div>

<%# Spacious variant %>
<div class="observ-stat-list observ-stat-list--spacious">
  ...
</div>
```

### Definition List

For term/definition pairs:

```erb
<dl class="observ-definition-list">
  <div class="observ-definition-list__item">
    <dt class="observ-definition-list__term">Term</dt>
    <dd class="observ-definition-list__definition">Definition</dd>
  </div>
</dl>
```

### Code Blocks

```erb
<%# Inline code %>
<code class="observ-code">inline code</code>

<%# Code block %>
<pre class="observ-code-block">
  Multi-line code here
</pre>
```

### JSON Viewer

```erb
<div class="observ-json-viewer">
  <%= render_json(@data) %>
</div>

<%# Compact variant %>
<div class="observ-json-viewer observ-json-viewer--compact">
  <%= render_json(@data) %>
</div>
```

---

## Helpers

### Pagination

Always use the `observ_pagination` helper for consistent pagination:

```erb
<%= observ_pagination(@collection) %>
```

This renders:
- "Showing X-Y of Z" info text
- Styled pagination links

**Never use raw `paginate` calls** - they won't have proper styling.

### Text Utilities

```erb
<span class="observ-text--muted">Muted text</span>
<span class="observ-text--small">Small text</span>
<span class="observ-text--success">Success text</span>
<span class="observ-text--warning">Warning text</span>
<span class="observ-text--danger">Danger text</span>
<span class="observ-text--center">Centered text</span>
<span class="observ-text--right">Right-aligned text</span>
```

### Links

```erb
<%= link_to "Link text", path, class: "observ-link" %>
```

---

## Best Practices

### DO

1. **Use semantic color variables**
   ```scss
   // Good
   color: $observ-text-primary;
   background-color: $observ-bg-surface;
   ```

2. **Use spacing variables**
   ```scss
   // Good
   padding: $observ-spacing-md;
   margin-bottom: $observ-spacing-lg;
   ```

3. **Use BEM naming convention**
   ```scss
   // Good
   .observ-card { }
   .observ-card__header { }
   .observ-card--highlighted { }
   ```

4. **Wrap content in `observ-page__content` for proper spacing**
   ```erb
   <div class="observ-page__content">
     <div class="observ-grid observ-grid--2">...</div>
     <div class="observ-card">...</div>
   </div>
   ```

5. **Use `observ_pagination` helper for pagination**

### DON'T

1. **Don't use hardcoded colors**
   ```scss
   // Bad
   color: #ffffff;
   background-color: #1a1a2e;
   ```

2. **Don't use hardcoded spacing**
   ```scss
   // Bad
   padding: 16px;
   margin-bottom: 24px;
   ```

3. **Don't use generic class names**
   ```erb
   <!-- Bad -->
   <div class="card">
   <button class="btn">
   ```

4. **Don't add heavy hover effects on static content**
   ```scss
   // Bad - background change on non-interactive card
   .observ-card:hover {
     background-color: $observ-bg-hover;
   }
   
   // Good - subtle border highlight
   .observ-card:hover {
     border-color: $observ-border-strong;
   }
   ```

5. **Don't use raw `paginate` calls**
   ```erb
   <!-- Bad -->
   <%= paginate @items, theme: "observ" %>
   
   <!-- Good -->
   <%= observ_pagination(@items) %>
   ```

---

## File Structure

```
app/assets/stylesheets/observ/
├── application.scss      # Main entry point, imports all partials
├── _variables.scss       # All color, spacing, typography variables
├── _namespace.scss       # Scoping mixin
├── _reset.scss          # Base element resets
├── _layout.scss         # Sidebar, main wrapper, page structure
├── _card.scss           # Card component
├── _table.scss          # Table component
├── _components.scss     # Buttons, badges, forms, tabs, etc.
├── _pagination.scss     # Pagination styles
├── _chat.scss           # Chat message styles
├── _drawer.scss         # Slide-out drawer
├── _json_viewer.scss    # JSON syntax highlighting
├── _annotations.scss    # Annotation form/list styles
├── _dashboard.scss      # Dashboard-specific styles
├── _datasets.scss       # Dataset feature styles
├── _filters.scss        # Filter/search components
├── _metrics.scss        # Metric cards
├── _observations.scss   # Observation feature styles
└── _prompts.scss        # Prompt feature styles
```

---

## Adding New Components

When creating new components:

1. **Create styles in appropriate partial** or new partial if needed
2. **Use the namespace mixin**:
   ```scss
   @import 'variables';
   @import 'namespace';
   
   @include observ-scoped {
     .observ-new-component {
       // styles here
     }
   }
   ```
3. **Follow BEM naming**: `.observ-component__element--modifier`
4. **Use only variables** for colors, spacing, typography
5. **Document the component** in this styleguide
