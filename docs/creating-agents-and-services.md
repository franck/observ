# Creating Agents and Services

This guide explains how to create LLM-powered agents and services in this application. Follow this pattern when building new features that require AI interactions.

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Controller    │────▶│     Service     │────▶│      Agent      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │                        │
                              │                        ▼
                              │                 ┌─────────────────┐
                              │                 │     Schema      │
                              │                 │ (structured out)│
                              │                 └─────────────────┘
                              ▼
                        ┌─────────────────┐
                        │  Observability  │
                        │    (tracing)    │
                        └─────────────────┘
```

### Responsibilities

| Component | Responsibility |
|-----------|----------------|
| **Controller** | HTTP handling, parameter validation, calling service |
| **Service** | Business logic orchestration, data transformation, observability |
| **Agent** | LLM configuration (prompt, model, parameters, schema) |
| **Schema** | Structured output definition for type-safe responses |

## Step 1: Create the Agent

Agents define the LLM configuration: system prompt, model, parameters, and optional schema for structured output.

### File Location
`app/agents/<name>_agent.rb`

### Basic Structure

```ruby
# Schema for structured output (optional but recommended)
class MyFeatureSchema < RubyLLM::Schema
  @properties = {}
  @required_properties = []

  string :field_name,
         description: 'Description of this field',
         required: true

  array :items,
        of: :string,
        description: 'List of items',
        required: true

  integer :count,
          description: 'A numeric value',
          required: false
end

# Agent that handles <describe what it does>
#
# Uses structured output to ensure consistent data.
#
# Usage:
#   chat = RubyLLM.chat(model: MyFeatureAgent.model)
#   MyFeatureAgent.setup_instructions(chat)
#   response = chat.ask(prompt, output: MyFeatureAgent.schema)
#
class MyFeatureAgent < BaseAgent
  include Observ::PromptManagement

  FALLBACK_SYSTEM_PROMPT = <<~PROMPT
    You are an expert assistant in <domain>.

    ## YOUR ROLE

    <Describe the agent's role>

    ## PRINCIPLES

    1. **Principle 1**
       - Detail
       - Detail

    2. **Principle 2**
       - Detail

    ## OUTPUT FORMAT

    <Describe expected output format>
  PROMPT

  use_prompt_management(
    prompt_name: 'my-feature-agent-system-prompt',
    fallback: FALLBACK_SYSTEM_PROMPT
  )

  def self.schema
    MyFeatureSchema
  end

  def self.default_model
    'gpt-4o-mini'
  end

  def self.default_model_parameters
    {
      temperature: 0.7 # Adjust based on creativity needs
    }
  end

  # Build user prompt from context hash
  #
  # @param context [Hash] Context data (keys depend on use case)
  # @return [String] The formatted user prompt
  def self.build_user_prompt(context)
    <<~PROMPT
      <Task description>

      **Field 1** : #{context[:field1]}
      **Field 2** : #{context[:field2]}

      <Instructions>
    PROMPT
  end
end
```

### Key Points

1. **Schema first**: Define structured output schema for type-safe responses
2. **Agent is stateless**: All methods are class methods
3. **Hash-based context**: `build_user_prompt` accepts a Hash, not domain models
4. **Prompt management**: Use `Observ::PromptManagement` for editable prompts
5. **Temperature**: Lower (0.3-0.5) for factual, higher (0.7-0.9) for creative

## Step 2: Create the Service

Services orchestrate the business logic, handle data transformation, and manage observability.

### File Location
`app/services/<name>_service.rb`

### Basic Structure

```ruby
# <Describe what this service does>
#
# Usage:
#   service = MyFeatureService.new(input_data)
#   result = service.perform
#
# With observability:
#   session = Observ::Session.create!(user_id: "user_123")
#   service = MyFeatureService.new(input_data, observability_session: session)
#   result = service.perform
#
class MyFeatureService
  include Observ::Concerns::ObservableService

  def initialize(input_data, observability_session: nil)
    @input_data = input_data

    initialize_observability(
      observability_session,
      service_name: 'my_feature',
      metadata: { input_id: input_data.id }
    )
  end

  def perform
    with_observability do |_session|
      response = call_agent
      normalize_response(response)
    end
  rescue StandardError => e
    Rails.logger.error "[MyFeatureService] Failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    default_response
  end

  private

  def call_agent
    chat = RubyLLM.chat(model: MyFeatureAgent.model)
    chat.with_instructions(MyFeatureAgent.system_prompt)
    chat.with_schema(MyFeatureAgent.schema)

    model_params = MyFeatureAgent.model_parameters
    chat.with_params(**model_params) if model_params.any?

    # Instrument for observability
    instrument_chat(
      chat,
      context: {
        service: 'my_feature',
        agent_class: MyFeatureAgent,
        input_id: @input_data.id
      }
    )

    prompt = MyFeatureAgent.build_user_prompt(build_context)
    response = chat.ask(prompt)

    # Response.content is a Hash thanks to schema structured output
    symbolize_keys(response.content)
  end

  # Build context hash from domain model
  # This is where data transformation happens
  def build_context
    {
      field1: @input_data.some_field,
      field2: @input_data.other_field.truncate(1500)
    }
  end

  # Normalize response to ensure all expected fields are present
  def normalize_response(data)
    {
      field_name: data[:field_name] || 'Default value',
      items: Array(data[:items]),
      count: data[:count] || 0
    }
  end

  # Fallback response if LLM call fails
  def default_response
    {
      field_name: '',
      items: [],
      count: 0
    }
  end

  def symbolize_keys(hash)
    return hash unless hash.is_a?(Hash)

    hash.transform_keys(&:to_sym)
  end
end
```

### Key Points

1. **Include `Observ::Concerns::ObservableService`**: Provides observability infrastructure
2. **Initialize observability**: Call `initialize_observability` in constructor
3. **Wrap in `with_observability`**: Use the block for automatic session management
4. **Instrument chat**: Call `instrument_chat` before making LLM calls
5. **Data transformation**: `build_context` converts domain models to hashes
6. **Error handling**: Always provide fallback with `default_response`
7. **Normalize response**: Ensure consistent output structure

## Step 3: Wire Up the Controller

### File Location
`app/controllers/<namespace>/<name>_controller.rb`

### Example

```ruby
module Authenticated
  class MyFeaturesController < BaseController
    def generate
      service = MyFeatureService.new(@input_data)
      result = service.perform

      respond_to do |format|
        format.json { render json: result }
      end
    end
  end
end
```

## Step 4: Add Routes

### File Location
`config/routes.rb`

```ruby
namespace :authenticated do
  resources :my_features, only: [] do
    collection do
      post :generate
    end
  end
end
```

## Complete Example: Character Generation

Here's the complete implementation for reference:

### Agent (`app/agents/character_generator_agent.rb`)

```ruby
class CharacterGeneratorSchema < RubyLLM::Schema
  @properties = {}
  @required_properties = []

  string :name, description: 'Character name', required: true
  string :concept, description: 'One-sentence concept', required: true
  string :background, description: 'Backstory', required: true
  array :skills, of: :string, description: 'Skills list', required: true
  array :equipment, of: :string, description: 'Equipment list', required: true
  array :traits, of: :string, description: 'Personality traits', required: true
  string :goals, description: 'Objectives and motivations', required: true
end

class CharacterGeneratorAgent < BaseAgent
  include Observ::PromptManagement

  FALLBACK_SYSTEM_PROMPT = <<~PROMPT
    You are an expert assistant in character creation...
  PROMPT

  use_prompt_management(
    prompt_name: 'character-generator-agent-system-prompt',
    fallback: FALLBACK_SYSTEM_PROMPT
  )

  def self.schema
    CharacterGeneratorSchema
  end

  def self.default_model
    'gpt-4o-mini'
  end

  def self.default_model_parameters
    { temperature: 0.8 }
  end

  def self.build_user_prompt(context)
    <<~PROMPT
      Generate a player character for this scenario:

      **Genre**: #{context[:genre]}
      **Title**: #{context[:title]}
      **Synopsis**: #{context[:synopsis]}

      **Context**:
      #{context[:context]}

      Create an original and interesting character.
    PROMPT
  end
end
```

### Service (`app/services/character_generation_service.rb`)

```ruby
class CharacterGenerationService
  include Observ::Concerns::ObservableService

  def initialize(scenario, observability_session: nil)
    @scenario = scenario

    initialize_observability(
      observability_session,
      service_name: 'character_generation',
      metadata: { scenario_id: scenario.id, genre: scenario.genre }
    )
  end

  def generate
    with_observability do |_session|
      response = call_agent
      normalize_response(response)
    end
  rescue StandardError => e
    Rails.logger.error "[CharacterGenerationService] Failed: #{e.message}"
    default_character
  end

  private

  def call_agent
    chat = RubyLLM.chat(model: CharacterGeneratorAgent.model)
    chat.with_instructions(CharacterGeneratorAgent.system_prompt)
    chat.with_schema(CharacterGeneratorAgent.schema)

    model_params = CharacterGeneratorAgent.model_parameters
    chat.with_params(**model_params) if model_params.any?

    instrument_chat(chat, context: {
      service: 'character_generation',
      agent_class: CharacterGeneratorAgent,
      scenario_id: @scenario.id
    })

    prompt = CharacterGeneratorAgent.build_user_prompt(build_scenario_context)
    response = chat.ask(prompt)
    symbolize_keys(response.content)
  end

  def build_scenario_context
    {
      genre: @scenario.genre.humanize,
      title: @scenario.title,
      synopsis: @scenario.synopsis,
      context: @scenario.context.truncate(1500)
    }
  end

  def normalize_response(data)
    {
      name: data[:name] || 'Unnamed',
      concept: data[:concept] || '',
      background: data[:background] || '',
      skills: Array(data[:skills]),
      equipment: Array(data[:equipment]),
      traits: Array(data[:traits]),
      goals: data[:goals] || ''
    }
  end

  def default_character
    { name: '', concept: '', background: '', skills: [], equipment: [], traits: [], goals: '' }
  end

  def symbolize_keys(hash)
    hash.is_a?(Hash) ? hash.transform_keys(&:to_sym) : hash
  end
end
```

## Checklist

When creating a new agent/service pair:

- [ ] Create schema class with all output fields defined
- [ ] Create agent class extending `BaseAgent`
- [ ] Include `Observ::PromptManagement` in agent
- [ ] Define `FALLBACK_SYSTEM_PROMPT` constant
- [ ] Call `use_prompt_management` with prompt name
- [ ] Implement `schema`, `default_model`, `default_model_parameters`
- [ ] Implement `build_user_prompt(context)` accepting a Hash
- [ ] Create service class including `Observ::Concerns::ObservableService`
- [ ] Call `initialize_observability` in service constructor
- [ ] Wrap main method in `with_observability` block
- [ ] Implement `build_context` for data transformation
- [ ] Call `instrument_chat` before LLM calls
- [ ] Implement `normalize_response` for consistent output
- [ ] Implement `default_response` for error fallback
- [ ] Add controller action
- [ ] Add route
- [ ] Test the endpoint
