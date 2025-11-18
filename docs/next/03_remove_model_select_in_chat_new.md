# Task 3: Remove Model Select in Chat#new

## Overview
Remove the model selection dropdown from the chat creation form, simplifying the UX and relying on agent-specific model configuration instead.

## Current State
The chat form (`app/views/observ/chats/_form.html.erb`) currently has two select fields:
1. **Model select** (lines 14-22) - Allows users to choose AI model
2. **Agent select** (lines 24-30) - Allows users to choose agent type

```erb
<div class="observ-form-group">
  <%= form.label :model, "Select AI model:", class: "observ-label" %>
  <%= form.select :model, 
    options_for_select(
      Model.pluck(:name, :model_id).unshift(["Default (#{RubyLLM.config.default_model})", RubyLLM.config.default_model]), 
      @selected_model
    ), 
    {}, 
    class: "observ-select" %>
</div>
```

The controller (`app/controllers/observ/chats_controller.rb:30`) sets a default model:
```ruby
def params_chat
  params.require(:chat).permit(:model, :agent_class_name).with_defaults(model: RubyLLM.config.default_model)
end
```

## Problem Statement
1. **Redundant configuration** - Users shouldn't need to choose both model and agent
2. **Confusion** - Users may not know which model works best with which agent
3. **Agent responsibility** - Agents should determine their own model requirements
4. **Consistency** - Model selection should be agent-driven, not user-driven in this context

## Proposed Solution

### Phase 1: Update Form View
Remove model selection from `app/views/observ/chats/_form.html.erb`:

**Before:**
```erb
<div class="observ-form-group">
  <%= form.label :model, "Select AI model:", class: "observ-label" %>
  <%= form.select :model, 
    options_for_select(
      Model.pluck(:name, :model_id).unshift(["Default (#{RubyLLM.config.default_model})", RubyLLM.config.default_model]), 
      @selected_model
    ), 
    {}, 
    class: "observ-select" %>
</div>

<div class="observ-form-group">
  <%= form.label :agent_class_name, "Select Agent Type:", class: "observ-label" %>
  <%= form.select :agent_class_name, 
    agent_select_options, 
    {}, 
    class: "observ-select" %>
</div>
```

**After:**
```erb
<div class="observ-form-group">
  <%= form.label :agent_class_name, "Select Agent Type:", class: "observ-label" %>
  <%= form.select :agent_class_name, 
    agent_select_options, 
    {}, 
    class: "observ-select" %>
  <p class="observ-form-help-text">
    Each agent uses its optimally configured model.
  </p>
</div>
```

### Phase 2: Update Controller
The controller already has a default model fallback, so we just need to ensure it's not exposed to the form.

**Keep in `params_chat`:**
```ruby
def params_chat
  params.require(:chat).permit(:agent_class_name).with_defaults(model: RubyLLM.config.default_model)
end
```

Note: Still permit `agent_class_name` but remove `:model` from permitted params since it won't be in the form anymore. Keep the default fallback for backward compatibility.

### Phase 3: Agent Model Configuration
Ensure agents can specify their preferred models. This may already exist, but document the pattern:

```ruby
class DeepResearchAgent < BaseAgent
  def self.default_model
    "gpt-4-turbo-preview"
  end
  
  def initialize(*args)
    super
    @model = self.class.default_model
  end
end
```

### Phase 4: Update Chat Model
If needed, update the Chat model to get model from agent:

```ruby
class Chat < ApplicationRecord
  before_validation :set_model_from_agent, if: :agent_class_name_changed?
  
  private
  
  def set_model_from_agent
    return unless agent_class_name.present?
    
    agent_class = agent_class_name.constantize
    self.model = agent_class.default_model if agent_class.respond_to?(:default_model)
  rescue NameError
    # Agent class not found, keep current model
  end
end
```

### Phase 5: Update Tests
Update controller and feature tests:

**spec/requests/observ/chats_controller_spec.rb:**
```ruby
describe "POST /create" do
  it "creates a chat with default model when no model specified" do
    post chats_path, params: { chat: { agent_class_name: "DeepResearchAgent" } }
    
    expect(Chat.last.model).to eq(RubyLLM.config.default_model)
  end
  
  it "creates a chat with agent's default model" do
    # Test that agent's default model is used
  end
end
```

**spec/features/observ/chats_spec.rb:**
```ruby
scenario "user creates a new chat" do
  visit new_chat_path
  
  expect(page).not_to have_select("Select AI model")
  expect(page).to have_select("Select Agent Type")
  
  select "Deep Research", from: "Select Agent Type"
  click_button "Start new chat"
  
  expect(page).to have_content("Chat was successfully created")
end
```

### Phase 6: Documentation
Update any user-facing documentation about chat creation to reflect the simplified flow.

## Files to Modify
- `app/views/observ/chats/_form.html.erb` - Remove model select, add help text
- `app/controllers/observ/chats_controller.rb` - Update params_chat to not permit :model from form
- `app/models/chat.rb` - Add callback to set model from agent (if needed)
- `spec/requests/observ/chats_controller_spec.rb` - Update tests
- `spec/features/observ/chats_spec.rb` - Update feature tests

## Files to Review
- Agent implementations - Ensure they specify default models
- `app/models/base_agent.rb` - Check if default_model pattern exists

## Benefits
1. **Simplified UX** - One less decision for users to make
2. **Better defaults** - Agents use their optimal models
3. **Less confusion** - No model/agent mismatch issues
4. **Cleaner form** - Streamlined interface

## Considerations
- **Backward compatibility** - Existing chats with specific models should continue working
- **Model override** - Should advanced users be able to override model somewhere else?
- **Agent requirements** - All agents must specify default models
- **Migration path** - No database changes needed, just form/controller updates

## Alternatives Considered
1. **Keep both selects** - Rejected: too complex for users
2. **Auto-populate model based on agent** - Rejected: still shows unnecessary field
3. **Advanced settings toggle** - Could add model override in advanced settings later if needed

## Notes
This change is purely presentational/UX - the underlying model still exists and functions the same way, it's just not exposed in the simple chat creation form.
