# Task 2: Add Pagination with View Helper

## Overview
Implement pagination across all index pages (chats, sessions, traces, observations, prompts, annotations) using a consistent view helper approach.

## Current State
### Already Paginated
The following controllers already use Kaminari pagination:
- **SessionsController#index** - `@sessions.page(params[:page]).per(25)` (app/controllers/observ/sessions_controller.rb:6)
- **ObservationsController#index** - `@observations.page(params[:page]).per(25)` (app/controllers/observ/observations_controller.rb:7-8)
- **TracesController#index** - `@traces.page(params[:page]).per(25)` (app/controllers/observ/traces_controller.rb:7-8)
- **PromptsController#index** - `@prompts.page(params[:page]).per(25)` (app/controllers/observ/prompts_controller.rb:22)

### Not Paginated Yet
- **ChatsController#index** - `@chats = ::Chat.order(created_at: :desc)` (app/controllers/observ/chats_controller.rb:6)
- **AnnotationsController#sessions_index** - No pagination (app/controllers/observ/annotations_controller.rb:10-11)
- **AnnotationsController#traces_index** - No pagination (app/controllers/observ/annotations_controller.rb:14-16)

## Problems with Current Implementation

1. **Inconsistent per-page values** - Some use 25, need to verify all are consistent
2. **No centralized pagination helper** - Pagination UI must be manually added to each view
3. **Duplicated pagination HTML** - Each view has its own pagination markup (if any)
4. **No pagination info display** - Missing "Showing 1-25 of 100" type messages
5. **No configuration option** - Per-page value is hardcoded in each controller

## Proposed Solution

### Phase 1: Create Centralized Pagination Configuration
Add configuration to `lib/observ/configuration.rb`:
```ruby
module Observ
  class Configuration
    attr_accessor :pagination_per_page
    
    def initialize
      @pagination_per_page = 25
    end
  end
end
```

### Phase 2: Create Pagination View Helper
Create `app/helpers/observ/pagination_helper.rb`:
```ruby
module Observ
  module PaginationHelper
    # Renders pagination controls with info
    # Usage: <%= observ_pagination(@collection) %>
    def observ_pagination(collection)
      return unless collection.respond_to?(:current_page)
      
      content_tag(:div, class: "observ-pagination") do
        safe_join([
          pagination_info(collection),
          pagination_links(collection)
        ])
      end
    end
    
    private
    
    def pagination_info(collection)
      content_tag(:div, class: "observ-pagination__info") do
        "Showing #{collection.offset_value + 1}-#{[collection.offset_value + collection.limit_value, collection.total_count].min} of #{collection.total_count}"
      end
    end
    
    def pagination_links(collection)
      content_tag(:div, class: "observ-pagination__links") do
        paginate collection, theme: 'observ'
      end
    end
  end
end
```

### Phase 3: Create Pagination Styles
Add to `app/assets/stylesheets/observ/components/_pagination.scss`:
```scss
.observ-pagination {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 0;
  margin-top: 2rem;
  border-top: 1px solid var(--observ-border-color);
  
  &__info {
    font-size: 0.875rem;
    color: var(--observ-text-muted);
  }
  
  &__links {
    display: flex;
    gap: 0.5rem;
  }
}
```

### Phase 4: Create Kaminari Theme
Generate and customize Kaminari views:
```bash
rails g kaminari:views observ
```

Customize generated views in `app/views/kaminari/observ/` to match Observ design system.

### Phase 5: Update Controllers
Update each controller to use consistent pagination:

**ChatsController:**
```ruby
def index
  @chats = ::Chat.order(created_at: :desc)
    .page(params[:page])
    .per(Observ.config.pagination_per_page)
end
```

**AnnotationsController:**
```ruby
def sessions_index
  @sessions = Observ::Session.joins(:annotations)
    .distinct
    .order(created_at: :desc)
    .page(params[:page])
    .per(Observ.config.pagination_per_page)
    
  @annotations = Observ::Annotation
    .where(annotatable_type: "Observ::Session")
    .includes(:annotatable)
    .order(created_at: :desc)
    .page(params[:page])
    .per(Observ.config.pagination_per_page)
end

def traces_index
  @traces = Observ::Trace.joins(:annotations)
    .distinct
    .order(created_at: :desc)
    .page(params[:page])
    .per(Observ.config.pagination_per_page)
    
  @annotations = Observ::Annotation
    .where(annotatable_type: "Observ::Trace")
    .includes(:annotatable)
    .order(created_at: :desc)
    .page(params[:page])
    .per(Observ.config.pagination_per_page)
end
```

Update existing paginated controllers to use `Observ.config.pagination_per_page` instead of hardcoded 25.

### Phase 6: Update Views
Add pagination helper to all index views:

**app/views/observ/chats/index.html.erb:**
```erb
<div class="observ-table-container">
  <!-- table content -->
</div>

<%= observ_pagination(@chats) %>
```

Apply to all other index views:
- `app/views/observ/sessions/index.html.erb`
- `app/views/observ/traces/index.html.erb`
- `app/views/observ/observations/index.html.erb`
- `app/views/observ/prompts/index.html.erb`
- `app/views/observ/annotations/sessions_index.html.erb`
- `app/views/observ/annotations/traces_index.html.erb`

### Phase 7: Testing
Create comprehensive tests:

**spec/helpers/observ/pagination_helper_spec.rb:**
- Test helper renders pagination info
- Test helper renders pagination links
- Test helper handles empty collections
- Test helper handles single page collections

**Controller specs:**
- Test pagination parameters are applied
- Test per_page configuration is respected
- Test pagination metadata is included

**Feature specs:**
- Test user can navigate between pages
- Test pagination info displays correctly
- Test pagination works with filters

## Files to Create
- `app/helpers/observ/pagination_helper.rb` - Pagination view helper
- `app/assets/stylesheets/observ/components/_pagination.scss` - Pagination styles
- `app/views/kaminari/observ/` - Kaminari theme templates
- `spec/helpers/observ/pagination_helper_spec.rb` - Helper tests

## Files to Modify
- `lib/observ/configuration.rb` - Add pagination_per_page configuration
- `app/controllers/observ/chats_controller.rb` - Add pagination
- `app/controllers/observ/annotations_controller.rb` - Add pagination to index actions
- `app/controllers/observ/sessions_controller.rb` - Use config for per_page
- `app/controllers/observ/traces_controller.rb` - Use config for per_page
- `app/controllers/observ/observations_controller.rb` - Use config for per_page
- `app/controllers/observ/prompts_controller.rb` - Use config for per_page
- `app/views/observ/chats/index.html.erb` - Add pagination helper
- `app/views/observ/sessions/index.html.erb` - Add pagination helper
- `app/views/observ/traces/index.html.erb` - Add pagination helper
- `app/views/observ/observations/index.html.erb` - Add pagination helper
- `app/views/observ/prompts/index.html.erb` - Add pagination helper
- `app/views/observ/annotations/sessions_index.html.erb` - Add pagination helper
- `app/views/observ/annotations/traces_index.html.erb` - Add pagination helper
- `app/assets/stylesheets/observ/application.scss` - Import pagination styles

## Benefits
1. **Consistency** - All index pages have the same pagination UI/UX
2. **Maintainability** - Single source of truth for pagination markup
3. **Configurability** - Easy to change per_page value globally
4. **User Experience** - Clear pagination info and navigation
5. **Performance** - Prevents loading all records at once

## Considerations
- Default per_page value (25 seems reasonable)
- Should per_page be overridable per controller?
- Mobile responsiveness of pagination controls
- Accessibility (keyboard navigation, ARIA labels)
- Should we support infinite scroll as an alternative?
