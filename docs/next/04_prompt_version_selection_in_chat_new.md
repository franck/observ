# Task 4: Prompt Version Selection in Chat#new

## Overview
After selecting an agent in the chat creation form, if the agent uses prompt management, display a select field to choose a specific prompt version or use the default (production) prompt.

## Current State
- Chat form has only agent selection (`app/views/observ/chats/_form.html.erb`)
- No prompt version selection exists
- Agents may or may not use prompt management
- Prompt model has version management with states (draft/production/archived)
- Production prompts are the default when fetching by name

## Problem Statement
1. **No version control in chat** - Users can't test specific prompt versions in chat interface
2. **Missing integration** - Prompt management system exists but isn't connected to chat UI
3. **Testing limitation** - Users can't compare different prompt versions in live chat
4. **Implicit behavior** - Users don't know which prompt version is being used

## Proposed Solution

### Phase 1: Detect Agent Prompt Usage
First, we need a way to determine if an agent uses prompt management.

Add to `app/models/base_agent.rb` (or create interface):
```ruby
module Observ
  module AgentPromptable
    extend ActiveSupport::Concern
    
    class_methods do
      # Returns the prompt name this agent uses
      # Override in agent classes that use prompts
      def prompt_name
        nil
      end
      
      # Check if this agent uses prompt management
      def uses_prompts?
        prompt_name.present?
      end
    end
  end
end
```

Example agent implementation:
```ruby
class DeepResearchAgent < BaseAgent
  include Observ::AgentPromptable
  
  def self.prompt_name
    "deep_research_system"
  end
end
```

### Phase 2: Add Prompt Version Field to Chat Model
Add migration to support prompt version tracking:
```ruby
class AddPromptVersionToChats < ActiveRecord::Migration[7.0]
  def change
    add_column :chats, :prompt_version, :integer, null: true
    add_column :chats, :prompt_name, :string, null: true
  end
end
```

### Phase 3: Create Stimulus Controller for Dynamic Form
Create `app/assets/javascripts/observ/controllers/chat_form_controller.js`:
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["agentSelect", "promptVersionGroup", "promptVersionSelect"]
  static values = { 
    promptsUrl: String,
    agentsWithPrompts: Object  // Map of agent_name => prompt_name
  }
  
  connect() {
    this.togglePromptVersionField()
  }
  
  agentChanged() {
    this.togglePromptVersionField()
  }
  
  togglePromptVersionField() {
    const selectedAgent = this.agentSelectTarget.value
    const promptName = this.agentsWithPromptsValue[selectedAgent]
    
    if (promptName) {
      this.loadPromptVersions(promptName)
      this.showPromptVersionField()
    } else {
      this.hidePromptVersionField()
    }
  }
  
  loadPromptVersions(promptName) {
    fetch(`${this.promptsUrlValue}/${promptName}/versions.json`)
      .then(response => response.json())
      .then(data => this.populateVersions(data))
  }
  
  populateVersions(versions) {
    this.promptVersionSelectTarget.innerHTML = this.buildVersionOptions(versions)
  }
  
  buildVersionOptions(versions) {
    const defaultOption = '<option value="">Use default (production)</option>'
    const versionOptions = versions.map(v => 
      `<option value="${v.version}">v${v.version} - ${v.state} ${v.commit_message ? '- ' + v.commit_message : ''}</option>`
    ).join('')
    
    return defaultOption + versionOptions
  }
  
  showPromptVersionField() {
    this.promptVersionGroupTarget.classList.remove('hidden')
  }
  
  hidePromptVersionField() {
    this.promptVersionGroupTarget.classList.add('hidden')
  }
}
```

### Phase 4: Update Chat Form View
Update `app/views/observ/chats/_form.html.erb`:
```erb
<%= form_with(model: chat, url: chats_path, data: { 
  controller: "observ--chat-form",
  observ__chat_form_prompts_url_value: prompts_path,
  observ__chat_form_agents_with_prompts_value: agents_with_prompts_map.to_json
}) do |form| %>
  
  <% if chat.errors.any? %>
    <!-- error messages -->
  <% end %>

  <div class="observ-form-group">
    <%= form.label :agent_class_name, "Select Agent Type:", class: "observ-label" %>
    <%= form.select :agent_class_name, 
      agent_select_options, 
      {}, 
      class: "observ-select",
      data: { 
        observ__chat_form_target: "agentSelect",
        action: "change->observ--chat-form#agentChanged"
      } %>
  </div>

  <div class="observ-form-group hidden" 
       data-observ--chat-form-target="promptVersionGroup">
    <%= form.label :prompt_version, "Select Prompt Version:", class: "observ-label" %>
    <%= form.select :prompt_version,
      [],
      {},
      class: "observ-select",
      data: { observ__chat_form_target: "promptVersionSelect" } %>
    <p class="observ-form-help-text">
      Leave as default to use the production version, or select a specific version to test.
    </p>
  </div>

  <div>
    <%= form.submit "Start new chat", class: "observ-button observ-button--primary" %>
  </div>
<% end %>
```

### Phase 5: Add Helper Method
Create helper in `app/helpers/observ/chats_helper.rb`:
```ruby
def agents_with_prompts_map
  Observ::AgentProvider.all_agents.each_with_object({}) do |agent_class, hash|
    if agent_class.respond_to?(:uses_prompts?) && agent_class.uses_prompts?
      hash[agent_class.agent_identifier] = agent_class.prompt_name
    end
  end
end
```

### Phase 6: Add Prompts API Endpoint
Add to `app/controllers/observ/prompts_controller.rb`:
```ruby
# GET /observ/prompts/:id/versions.json
def versions
  @versions = Observ::Prompt.where(name: @prompt_name).order(version: :desc)
  
  respond_to do |format|
    format.html # existing HTML view
    format.json { render json: @versions.as_json(only: [:version, :state, :commit_message, :created_at]) }
  end
end
```

Add route in `config/routes.rb`:
```ruby
namespace :observ do
  resources :prompts do
    member do
      get :versions # Already exists for HTML
    end
  end
end
```

### Phase 7: Update Controller to Handle Prompt Version
Update `app/controllers/observ/chats_controller.rb`:
```ruby
def create
  @chat = ::Chat.new(params_chat)
  
  # Set prompt name from agent if applicable
  set_prompt_info_from_agent
  
  if @chat.save
    redirect_to chat_path(@chat), notice: "Chat was successfully created."
  else
    render :new, status: :unprocessable_content
  end
end

private

def params_chat
  params.require(:chat).permit(:agent_class_name, :prompt_version)
    .with_defaults(model: RubyLLM.config.default_model)
end

def set_prompt_info_from_agent
  return unless @chat.agent_class_name.present?
  
  agent_class = @chat.agent_class_name.constantize
  if agent_class.respond_to?(:prompt_name)
    @chat.prompt_name = agent_class.prompt_name
  end
rescue NameError
  # Agent class not found
end
```

### Phase 8: Use Prompt Version in Chat
Update agent initialization to use specified prompt version:
```ruby
class Chat < ApplicationRecord
  def agent_instance
    return @agent_instance if @agent_instance
    
    agent_class = agent_class_name.constantize
    @agent_instance = agent_class.new
    
    # If chat has a specific prompt version, use it
    if prompt_name.present? && prompt_version.present?
      @agent_instance.prompt_version = prompt_version
    end
    
    @agent_instance
  end
end
```

Or in the agent:
```ruby
class BaseAgent
  attr_accessor :prompt_version
  
  def system_prompt
    if self.class.uses_prompts?
      fetch_prompt_version
    else
      default_system_prompt
    end
  end
  
  private
  
  def fetch_prompt_version
    if prompt_version.present?
      Observ::Prompt.fetch(
        name: self.class.prompt_name, 
        version: prompt_version
      ).compile
    else
      Observ::Prompt.fetch(
        name: self.class.prompt_name, 
        state: :production
      ).compile
    end
  end
end
```

### Phase 9: Testing
Create comprehensive tests:

**spec/features/observ/chat_prompt_selection_spec.rb:**
```ruby
require 'rails_helper'

RSpec.feature "Chat prompt version selection", type: :feature, js: true do
  let!(:prompt_v1) { create(:observ_prompt, name: "test_prompt", version: 1, state: :production) }
  let!(:prompt_v2) { create(:observ_prompt, name: "test_prompt", version: 2, state: :draft) }
  
  scenario "user selects agent without prompts" do
    visit new_chat_path
    
    select "Default Agent", from: "Select Agent Type"
    
    expect(page).not_to have_select("Select Prompt Version")
  end
  
  scenario "user selects agent with prompts" do
    visit new_chat_path
    
    select "Deep Research", from: "Select Agent Type"
    
    expect(page).to have_select("Select Prompt Version")
    expect(page).to have_select("Select Prompt Version", options: [
      "Use default (production)",
      "v2 - draft",
      "v1 - production"
    ])
  end
  
  scenario "user creates chat with specific prompt version" do
    visit new_chat_path
    
    select "Deep Research", from: "Select Agent Type"
    select "v2 - draft", from: "Select Prompt Version"
    click_button "Start new chat"
    
    expect(Chat.last.prompt_version).to eq(2)
  end
end
```

## Files to Create
- `app/assets/javascripts/observ/controllers/chat_form_controller.js` - Stimulus controller
- `app/models/concerns/observ/agent_promptable.rb` - Agent prompt interface
- `db/migrate/XXXXXX_add_prompt_version_to_chats.rb` - Migration
- `spec/features/observ/chat_prompt_selection_spec.rb` - Feature tests

## Files to Modify
- `app/views/observ/chats/_form.html.erb` - Add prompt version select
- `app/controllers/observ/chats_controller.rb` - Handle prompt version param
- `app/controllers/observ/prompts_controller.rb` - Add JSON endpoint for versions
- `app/helpers/observ/chats_helper.rb` - Add agents_with_prompts_map helper
- `app/models/chat.rb` - Store and use prompt version
- `app/models/base_agent.rb` - Support prompt version override
- `config/routes.rb` - Ensure versions endpoint returns JSON

## Benefits
1. **Testing capability** - Test draft prompts before promoting to production
2. **Version comparison** - Compare prompt versions side-by-side in chat
3. **Transparency** - Users know which prompt version is active
4. **Flexibility** - Support both default and specific version selection
5. **Integration** - Connects prompt management to chat interface

## Considerations
- **Performance** - Loading prompt versions via AJAX on agent change
- **Caching** - Cache prompt versions list for performance
- **Backward compatibility** - Chats without prompt_version use production default
- **Agent interface** - Need consistent way for agents to declare prompt usage
- **Error handling** - What if selected prompt version is deleted?

## Future Enhancements
- Show prompt diff when comparing versions
- Indicate which version is currently production
- Allow cloning chat with different prompt version
- Track prompt version performance metrics per chat
