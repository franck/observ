# Dark Theme Implementation Plan

Inspired by Better Stack's incident detail UI, this document outlines the plan to migrate Observ from a light theme to a modern dark theme.

## Reference Design

**Source:** Better Stack incident detail page (`docs/screenshot-2025-11-27_11-05-16.png`)

**Key characteristics:**
- Deep navy/dark gray background
- Card-based layout with subtle borders (not heavy shadows)
- Clean typography with good contrast
- Green accent for success/resolved states
- Purple accent for AI features
- Action bars with icon+text buttons
- 3-column metadata grids
- Tab navigation with underline indicators

---

## Phase 1: Color System Foundation

### 1.1 Define Dark Theme Colors in `_variables.scss`

Add new dark theme semantic colors:

```scss
// Dark Theme - Base colors (Better Stack inspired)
$observ-dark-bg-page: #0d0d1a;        // Deep navy page background
$observ-dark-bg-surface: #1a1a2e;     // Card/surface background
$observ-dark-bg-elevated: #252540;    // Elevated elements (dropdowns, modals)
$observ-dark-bg-hover: #2a2a45;       // Hover states

// Dark Theme - Borders
$observ-dark-border: #2a2a40;         // Standard border
$observ-dark-border-subtle: #1f1f35;  // Subtle dividers
$observ-dark-border-strong: #3a3a55;  // Emphasized borders

// Dark Theme - Text
$observ-dark-text-primary: #f3f4f6;   // Primary text (gray-100)
$observ-dark-text-secondary: #9ca3af; // Secondary text (gray-400)
$observ-dark-text-muted: #6b7280;     // Muted text (gray-500)

// Accent colors (keep existing, add purple for AI)
$observ-purple: #a78bfa;              // AI/special features accent
```

### 1.2 Create Semantic Color Mappings

Replace direct color usage with semantic variables:

```scss
// Semantic mappings (dark theme as default)
$observ-bg-page: $observ-dark-bg-page;
$observ-bg-surface: $observ-dark-bg-surface;
$observ-bg-elevated: $observ-dark-bg-elevated;
$observ-bg-hover: $observ-dark-bg-hover;

$observ-border-color: $observ-dark-border;
$observ-border-subtle: $observ-dark-border-subtle;
$observ-border-strong: $observ-dark-border-strong;

$observ-text-primary: $observ-dark-text-primary;
$observ-text-secondary: $observ-dark-text-secondary;
$observ-text-muted: $observ-dark-text-muted;
```

**Files to modify:**
- `app/assets/stylesheets/observ/_variables.scss`

**Estimated effort:** 30 minutes

---

## Phase 2: Core Layout Components

### 2.1 Main Layout (`_layout.scss`)

Update `.observ-layout`:
- Background: `$observ-bg-page`
- Text color: `$observ-text-primary`

Update `.observ-main`:
- Remove light background
- Ensure proper text inheritance

Update `.observ-footer`:
- Dark background with subtle top border

**Files to modify:**
- `app/assets/stylesheets/observ/_layout.scss`

**Estimated effort:** 20 minutes

### 2.2 Navigation (`_navigation.scss`)

Update `.observ-nav`:
- Background: `$observ-bg-surface`
- Border-bottom instead of shadow
- Link colors: `$observ-text-secondary` default, `$observ-text-primary` on hover
- Active link: Blue background with white text (keep current pattern)

Update `.observ-nav__dropdown`:
- Dark dropdown background
- Subtle border

**Files to modify:**
- `app/assets/stylesheets/observ/_navigation.scss`

**Estimated effort:** 30 minutes

---

## Phase 3: Card System

### 3.1 Cards (`_card.scss`)

Update `.observ-card`:
- Background: `$observ-bg-surface`
- Border: 1px solid `$observ-border-color`
- Remove or reduce shadows
- Hover: subtle background change instead of elevation

Update `.observ-card__header`:
- Border color: `$observ-border-subtle`
- Title color: `$observ-text-primary`

Update `.observ-card__footer`:
- Background: slightly darker than card
- Border color: `$observ-border-subtle`

**Files to modify:**
- `app/assets/stylesheets/observ/_card.scss`

**Estimated effort:** 30 minutes

### 3.2 Metric Cards (`_metrics.scss`)

Update metric cards to use dark surfaces:
- Same card styling as base cards
- Trend indicators: keep green/red for positive/negative
- Highlighted variant: use subtle gradient with primary color

**Files to modify:**
- `app/assets/stylesheets/observ/_metrics.scss`

**Estimated effort:** 20 minutes

---

## Phase 4: Data Display Components

### 4.1 Tables (`_table.scss`)

Update `.observ-table`:
- Header background: `$observ-bg-elevated`
- Row borders: `$observ-border-subtle`
- Hover: `$observ-bg-hover`
- Text colors: primary for data, secondary for labels

**Files to modify:**
- `app/assets/stylesheets/observ/_table.scss`

**Estimated effort:** 25 minutes

### 4.2 JSON Viewer (`_json_viewer.scss`)

Already uses dark theme - minimal changes needed:
- Ensure consistent with new color system
- Update any hardcoded colors to use variables

**Files to modify:**
- `app/assets/stylesheets/observ/_json_viewer.scss`

**Estimated effort:** 15 minutes

---

## Phase 5: Form Components

### 5.1 Buttons (`_components.scss`)

Update `.observ-button`:
- Primary: keep blue background
- Secondary: `$observ-bg-elevated` with light text
- Danger: red outline on dark
- Link: `$observ-text-secondary`, hover `$observ-text-primary`

**Estimated effort:** 20 minutes

### 5.2 Form Inputs (`_forms.scss`)

Update inputs, selects, textareas:
- Background: `$observ-bg-elevated`
- Border: `$observ-border-color`
- Text: `$observ-text-primary`
- Placeholder: `$observ-text-muted`
- Focus: blue border (keep current)

**Files to modify:**
- `app/assets/stylesheets/observ/_forms.scss`

**Estimated effort:** 30 minutes

---

## Phase 6: Feedback Components

### 6.1 Badges (`_components.scss`)

Update badge backgrounds for dark theme contrast:
- Success: dark green tint with green text
- Danger: dark red tint with red text
- Warning: dark amber tint with amber text
- Info: dark cyan tint with cyan text
- Default: `$observ-bg-elevated` with gray text

**Estimated effort:** 20 minutes

### 6.2 Alerts (`_layout.scss` or `_components.scss`)

Update flash messages:
- Dark backgrounds with colored left border
- Appropriate text contrast

**Estimated effort:** 15 minutes

---

## Phase 7: Overlay Components

### 7.1 Drawer (`_drawer.scss`)

Update `.observ-drawer`:
- Background: `$observ-bg-surface`
- Header border: `$observ-border-subtle`
- Overlay: darken to 0.7 opacity

**Files to modify:**
- `app/assets/stylesheets/observ/_drawer.scss`

**Estimated effort:** 20 minutes

### 7.2 Dropdowns

Update dropdown menus:
- Background: `$observ-bg-elevated`
- Border: `$observ-border-color`
- Hover: `$observ-bg-hover`

**Estimated effort:** 15 minutes

---

## Phase 8: Pagination & Misc

### 8.1 Pagination (`_pagination.scss`)

Update pagination controls:
- Default: `$observ-bg-elevated` buttons
- Active: blue background
- Hover: `$observ-bg-hover`

**Files to modify:**
- `app/assets/stylesheets/observ/_pagination.scss`

**Estimated effort:** 15 minutes

### 8.2 Empty States

Update empty state styling:
- Muted text colors
- Icon colors

**Estimated effort:** 10 minutes

---

## Phase 9: New UI Patterns (from Better Stack)

### 9.1 Action Bar Component

Create new pattern for horizontal action buttons:

```scss
.observ-action-bar {
  display: flex;
  gap: $observ-spacing-md;
  padding: $observ-spacing-sm 0;
  
  &__button {
    display: inline-flex;
    align-items: center;
    gap: $observ-spacing-xs;
    color: $observ-text-secondary;
    
    &:hover {
      color: $observ-text-primary;
    }
    
    svg {
      width: 1rem;
      height: 1rem;
    }
  }
}
```

**Estimated effort:** 20 minutes

### 9.2 Info Grid Component

Create 3-column metadata display:

```scss
.observ-info-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: $observ-spacing-md;
  
  &__item {
    padding: $observ-spacing-md;
    border: 1px solid $observ-border-color;
    border-radius: $observ-border-radius;
  }
  
  &__label {
    font-size: $observ-font-size-sm;
    color: $observ-text-muted;
    margin-bottom: $observ-spacing-xs;
  }
  
  &__value {
    font-size: $observ-font-size-lg;
    font-weight: 600;
    color: $observ-text-primary;
  }
}
```

**Estimated effort:** 20 minutes

### 9.3 AI Feature Highlight

Create purple-accented section for AI features:

```scss
.observ-ai-section {
  border-left: 3px solid $observ-purple;
  background: rgba($observ-purple, 0.1);
  padding: $observ-spacing-md;
  border-radius: $observ-border-radius;
  
  &__header {
    display: flex;
    align-items: center;
    gap: $observ-spacing-sm;
    color: $observ-purple;
    font-weight: 500;
    margin-bottom: $observ-spacing-sm;
  }
}
```

**Estimated effort:** 15 minutes

---

## Implementation Order

| Priority | Phase | Description | Effort |
|----------|-------|-------------|--------|
| 1 | Phase 1 | Color system foundation | 30 min |
| 2 | Phase 2 | Core layout & navigation | 50 min |
| 3 | Phase 3 | Card system | 50 min |
| 4 | Phase 4 | Tables & data display | 40 min |
| 5 | Phase 5 | Form components | 50 min |
| 6 | Phase 6 | Badges & alerts | 35 min |
| 7 | Phase 7 | Drawer & overlays | 35 min |
| 8 | Phase 8 | Pagination & misc | 25 min |
| 9 | Phase 9 | New UI patterns | 55 min |

**Total estimated effort:** ~6 hours

---

## Testing Checklist

After each phase, verify:

- [ ] Text is readable (sufficient contrast)
- [ ] Interactive elements have visible focus states
- [ ] Hover states are distinguishable
- [ ] Badges are readable on dark backgrounds
- [ ] Form inputs show clear boundaries
- [ ] Error/success states are visible
- [ ] Drawer overlay is visible but not opaque
- [ ] JSON viewer still looks correct
- [ ] Code blocks maintain readability

---

## Files to Modify (Summary)

```
app/assets/stylesheets/observ/
├── _variables.scss      # Phase 1
├── _layout.scss         # Phase 2
├── _navigation.scss     # Phase 2
├── _card.scss           # Phase 3
├── _metrics.scss        # Phase 3
├── _table.scss          # Phase 4
├── _json_viewer.scss    # Phase 4
├── _components.scss     # Phase 5, 6
├── _forms.scss          # Phase 5
├── _drawer.scss         # Phase 7
└── _pagination.scss     # Phase 8
```

---

## Rollback Strategy

If issues arise:
1. All changes are in SCSS files only (no view changes in early phases)
2. Git commit after each phase for easy rollback
3. Can maintain both light/dark variables and toggle via class if needed

---

## Future Enhancements

1. **Theme Toggle** - Add user preference for light/dark mode
2. **System Preference** - Respect `prefers-color-scheme` media query
3. **Sidebar Navigation** - Consider Better Stack's icon sidebar pattern
4. **Animations** - Subtle transitions between states
