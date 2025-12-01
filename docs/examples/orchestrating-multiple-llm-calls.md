# Orchestrating Multiple LLM Calls

This guide demonstrates patterns for building services that make multiple LLM calls, either in sequence or in combination with other operations like embedding searches.

## Overview

When building complex AI features, you often need to:
1. Call multiple LLM agents in sequence (pipeline pattern)
2. Combine embedding searches with LLM classification (retrieval-augmented generation)
3. Pass observability sessions across services for unified tracing

This document shows real-world patterns from production applications.

## Pattern 1: Sequential Agent Calls (Pipeline)

This pattern chains multiple LLM calls, where each step's output feeds the next.

### Use Case: Document Generation with Refinement

Generate a document, then refine it with a second specialized agent.

```ruby
# app/agents/document_generator_agent.rb
class DocumentGeneratorSchema < RubyLLM::Schema
  string :title, description: 'Document title', required: true
  string :content, description: 'Document body', required: true
  array :sections, of: :string, description: 'Section headings', required: true
end

class DocumentGeneratorAgent < BaseAgent
  include Observ::PromptManagement

  FALLBACK_SYSTEM_PROMPT = <<~PROMPT
    You are a technical document generator...
  PROMPT

  use_prompt_management(
    prompt_name: 'document-generator-system-prompt',
    fallback: FALLBACK_SYSTEM_PROMPT
  )

  def self.schema
    DocumentGeneratorSchema
  end

  def self.default_model
    'gpt-4o-mini'
  end
end

# app/agents/document_refiner_agent.rb
class DocumentRefinerSchema < RubyLLM::Schema
  string :refined_content, description: 'Improved document content', required: true
  array :improvements, of: :string, description: 'List of improvements made', required: true
end

class DocumentRefinerAgent < BaseAgent
  include Observ::PromptManagement

  FALLBACK_SYSTEM_PROMPT = <<~PROMPT
    You are an expert document editor and refiner...
  PROMPT

  use_prompt_management(
    prompt_name: 'document-refiner-system-prompt',
    fallback: FALLBACK_SYSTEM_PROMPT
  )

  def self.schema
    DocumentRefinerSchema
  end

  def self.default_model
    'gpt-4o-mini'
  end
end
```

### Service with Sequential Calls

```ruby
# app/services/document_creation_service.rb
class DocumentCreationService
  include Observ::Concerns::ObservableService

  def initialize(topic, observability_session: nil)
    @topic = topic

    initialize_observability(
      observability_session,
      service_name: 'document_creation',
      metadata: { topic: topic }
    )
  end

  def create
    with_observability do |session|
      # Step 1: Generate initial document
      initial_document = generate_document

      # Step 2: Refine the document
      refined = refine_document(initial_document)

      build_result(initial_document, refined)
    end
  rescue StandardError => e
    Rails.logger.error "[DocumentCreationService] Failed: #{e.message}"
    default_result
  end

  private

  # First LLM call: Generate document
  def generate_document
    chat = RubyLLM.chat(model: DocumentGeneratorAgent.model)
    chat.with_instructions(DocumentGeneratorAgent.system_prompt)
    chat.with_schema(DocumentGeneratorAgent.schema)

    model_params = DocumentGeneratorAgent.model_parameters
    chat.with_params(**model_params) if model_params.any?

    # Instrument for observability - this creates a trace for this specific call
    instrument_chat(
      chat,
      context: {
        service: 'document_creation',
        agent_class: DocumentGeneratorAgent,
        step: 'generation',
        topic: @topic
      }
    )

    prompt = "Create a comprehensive document about: #{@topic}"
    response = chat.ask(prompt)

    symbolize_keys(response.content)
  end

  # Second LLM call: Refine document
  def refine_document(initial_document)
    chat = RubyLLM.chat(model: DocumentRefinerAgent.model)
    chat.with_instructions(DocumentRefinerAgent.system_prompt)
    chat.with_schema(DocumentRefinerAgent.schema)

    model_params = DocumentRefinerAgent.model_parameters
    chat.with_params(**model_params) if model_params.any?

    # Instrument with different context - creates separate trace
    instrument_chat(
      chat,
      context: {
        service: 'document_creation',
        agent_class: DocumentRefinerAgent,
        step: 'refinement',
        initial_word_count: initial_document[:content].split.size
      }
    )

    prompt = <<~PROMPT
      Please refine and improve this document:

      Title: #{initial_document[:title]}
      Content: #{initial_document[:content]}

      Focus on clarity, structure, and completeness.
    PROMPT

    response = chat.ask(prompt)
    symbolize_keys(response.content)
  end

  def build_result(initial, refined)
    {
      title: initial[:title],
      content: refined[:refined_content],
      sections: initial[:sections],
      improvements: refined[:improvements],
      metadata: {
        generated_at: Time.current.iso8601,
        topic: @topic
      }
    }
  end

  def default_result
    { title: '', content: '', sections: [], improvements: [], metadata: {} }
  end

  def symbolize_keys(hash)
    hash.is_a?(Hash) ? hash.transform_keys(&:to_sym) : hash
  end
end
```

## Pattern 2: Orchestrating Multiple Services

When one service needs to call another service, pass the observability session to create a unified trace.

### Use Case: Scenario Generation with Mythic Seed

First generate a full scenario, then extract a lightweight seed from it.

```ruby
# app/services/scenario_generation_service.rb
class ScenarioGenerationService
  include Observ::Concerns::ObservableService

  def initialize(observability_session = nil)
    initialize_observability(
      observability_session,
      service_name: 'scenario_generation',
      metadata: {}
    )
  end

  def generate(user:, genre:, theme: nil)
    with_observability do |session|
      # Step 1: Generate scenario with Adventure Crafter agent
      scenario = perform_generation(user: user, genre: genre, theme: theme)

      # Step 2: Generate Mythic seed from the scenario
      # IMPORTANT: Pass the same session for unified observability
      begin
        mythic_seed_service = MythicSeedGeneratorService.new(session)
        mythic_seed = mythic_seed_service.generate(full_context: scenario.context)
        scenario.update!(mythic_seed: mythic_seed)
      rescue StandardError => e
        Rails.logger.error("[ScenarioGenerationService] Mythic seed generation failed: #{e.message}")
        # Continue even if mythic seed generation fails
      end

      scenario
    end
  end

  private

  def perform_generation(user:, genre:, theme:)
    chat = RubyLLM.chat(model: AdventureCrafterAgent.model)
    chat.with_instructions(AdventureCrafterAgent.system_prompt)
    chat.with_schema(AdventureCrafterAgent.schema)

    instrument_chat(
      chat,
      context: {
        service: 'scenario_generation',
        agent_class: AdventureCrafterAgent,
        genre: genre,
        theme: theme
      }
    )

    # ... rest of generation logic
  end
end

# app/services/mythic_seed_generator_service.rb
class MythicSeedGeneratorService
  include Observ::Concerns::ObservableService

  def initialize(observability_session = nil)
    initialize_observability(
      observability_session,
      service_name: 'mythic_seed_generation',
      metadata: {}
    )
  end

  def generate(full_context:)
    with_observability do |session|
      chat = RubyLLM.chat(model: MythicSeedAgent.model)
      chat.with_instructions(MythicSeedAgent.system_prompt)
      chat.with_schema(MythicSeedAgent.schema)

      instrument_chat(
        chat,
        context: {
          service: 'mythic_seed_generation',
          agent_class: MythicSeedAgent
        }
      )

      prompt = build_extraction_prompt(full_context)
      response = chat.ask(prompt)

      format_mythic_seed(response.content)
    end
  end
end
```

### Key Point: Session Passing

When the parent service passes its session to the child service:

```ruby
# Parent service creates or receives session
with_observability do |session|
  # Child service uses the SAME session
  child_service = ChildService.new(session)
  child_service.perform
end
```

Both services' LLM calls appear under the same observability session, giving you:
- Unified cost tracking
- Complete execution trace
- Parent-child relationship visibility in the UI

## Pattern 3: Embedding + LLM (RAG Pattern)

This pattern uses embeddings to find relevant data, then uses an LLM to process/classify it.

### Use Case: Narrative Consistency Checker

Find semantically related facts via embeddings, then use LLM to classify contradictions.

```ruby
# app/agents/consistency_checker_agent.rb
class FactComparisonSchema < RubyLLM::Schema
  string :classification,
         description: 'Classification of relationship',
         enum: %w[COMPATIBLE EVOLUTION CONTRADICTION UNRELATED],
         required: true

  string :explanation,
         description: 'Why this classification was chosen',
         required: true

  integer :existing_fact_id,
          description: 'ID of the existing fact being compared',
          required: true
end

class ConsistencyCheckSchema < RubyLLM::Schema
  array :comparisons,
        description: 'Comparison results for each fact',
        of: FactComparisonSchema,
        required: true

  array :warnings,
        description: 'Additional warnings or notes',
        of: :string,
        required: false
end

class ConsistencyCheckerAgent < BaseAgent
  include Observ::PromptManagement

  FALLBACK_SYSTEM_PROMPT = <<~PROMPT
    You are a narrative consistency analyst...
    
    <Classifications>
    - COMPATIBLE: No conflict between new content and existing fact
    - EVOLUTION: Natural progression/update of existing fact
    - CONTRADICTION: Direct conflict
    - UNRELATED: Existing fact not relevant to new content
    </Classifications>
  PROMPT

  use_prompt_management(
    prompt_name: 'consistency-checker-system-prompt',
    fallback: FALLBACK_SYSTEM_PROMPT
  )

  def self.schema
    ConsistencyCheckSchema
  end

  def self.default_model
    'gpt-4o-mini'
  end
end

# app/services/narrative_consistency_checker_service.rb
class NarrativeConsistencyCheckerService
  include Observ::Concerns::ObservableService

  SIMILARITY_THRESHOLD = 0.70
  MAX_RELATED_FACTS = 10

  def initialize(adventure, observability_session: nil)
    @adventure = adventure
    @embedding_service = EmbeddingService.new(observability_session)

    initialize_observability(
      observability_session,
      service_name: 'consistency_checker',
      metadata: { adventure_id: adventure.id }
    )
  end

  def check(new_content, context: nil)
    return empty_report(new_content) if new_content.blank?

    with_observability do |_session|
      perform_check(new_content, context)
    end
  end

  private

  def perform_check(new_content, context)
    # Step 1: Find related facts using embeddings (fast, cheap)
    related_facts = find_related_facts(new_content)

    return empty_report(new_content) if related_facts.empty?

    # Step 2: Use LLM to classify each relationship (more expensive, but targeted)
    classification_result = classify_fact_relationships(new_content, related_facts, context)

    # Step 3: Build the report
    build_report(new_content, related_facts, classification_result)
  rescue StandardError => e
    Rails.logger.error("[ConsistencyChecker] Check failed: #{e.message}")
    empty_report(new_content, warnings: ["Consistency check failed: #{e.message}"])
  end

  # Embedding-based retrieval (Step 1)
  def find_related_facts(content)
    embedding = @embedding_service.embed(content, purpose: 'consistency_check')
    return [] unless embedding

    # Query for similar facts using pgvector
    NarrativeFact
      .for_adventure(@adventure)
      .active
      .nearest_neighbors(:embedding, embedding, distance: :cosine)
      .first(MAX_RELATED_FACTS)
  end

  # LLM-based classification (Step 2)
  def classify_fact_relationships(new_content, related_facts, context)
    chat = RubyLLM.chat(model: ConsistencyCheckerAgent.model)
    chat.with_instructions(ConsistencyCheckerAgent.system_prompt)
    chat.with_schema(ConsistencyCheckerAgent.schema)

    instrument_chat(
      chat,
      context: {
        service: 'consistency_checker',
        adventure_id: @adventure.id,
        fact_count: related_facts.length
      }
    )

    prompt = build_classification_prompt(new_content, related_facts, context)
    response = chat.ask(prompt, **ConsistencyCheckerAgent.model_parameters)

    symbolize_response(response.content)
  end

  def build_classification_prompt(new_content, related_facts, context)
    parts = []

    parts << "<NewContent>\n#{new_content}\n</NewContent>"
    parts << "<Context>\n#{context}\n</Context>" if context.present?

    parts << '<ExistingFacts>'
    related_facts.each do |fact|
      parts << <<~FACT
        <Fact id="#{fact.id}" type="#{fact.fact_type}" subject="#{fact.subject}">
        #{fact.content}
        </Fact>
      FACT
    end
    parts << '</ExistingFacts>'

    parts.join("\n\n")
  end

  def build_report(new_content, related_facts, classification_result)
    comparisons = classification_result[:comparisons] || []
    warnings = classification_result[:warnings] || []

    facts_by_id = related_facts.index_by(&:id)
    contradictions = []
    evolutions = []

    comparisons.each do |comparison|
      fact = facts_by_id[comparison[:existing_fact_id]]
      next unless fact

      finding = {
        new_fact: new_content,
        existing_fact: fact,
        explanation: comparison[:explanation]
      }

      case comparison[:classification]
      when 'CONTRADICTION'
        contradictions << finding
      when 'EVOLUTION'
        evolutions << finding
      end
    end

    ConsistencyReport.new(
      contradictions: contradictions,
      evolutions: evolutions,
      warnings: warnings,
      checked_content: new_content,
      related_facts: related_facts
    )
  end

  def empty_report(content, warnings: [])
    ConsistencyReport.new(
      contradictions: [],
      evolutions: [],
      warnings: warnings,
      checked_content: content,
      related_facts: []
    )
  end

  def symbolize_response(content)
    content.is_a?(Hash) ? content.deep_transform_keys(&:to_sym) : {}
  end
end
```

### Why This Pattern Works

1. **Cost efficiency**: Embeddings are cheap and fast for retrieval
2. **Precision**: LLM only processes the most relevant items
3. **Scalability**: Can search millions of facts, but LLM only sees top 10

## Pattern 4: Service Calling Service with Different Responsibilities

When services extract facts and check consistency separately.

```ruby
# In MythicGMService - calls ConsistencyChecker before creating proposals
class MythicGMService
  include Observ::Concerns::ObservableService

  def initialize(adventure, observability_session: nil)
    @adventure = adventure

    initialize_observability(
      observability_session,
      service_name: 'mythic_gm',
      metadata: { adventure_id: adventure.id }
    )
  end

  def generate_gm_response(scene, player_message)
    with_observability do |_session|
      # Generate narrative response
      response = analyze_and_respond(scene, player_message)

      # Check consistency before creating proposal
      # Passes @observability (the session) to the checker service
      check_and_log_consistency(scene, response[:narrative])

      # Create the proposal
      scene.backstage_events.create!(
        event_type: :gm_proposal,
        proposal_status: :pending,
        details: { 'content' => response[:narrative] }
      )
    end
  end

  private

  def check_and_log_consistency(scene, narrative_content)
    return unless @adventure.narrative_facts.active.any?

    # Create checker with SAME session for unified observability
    checker = NarrativeConsistencyCheckerService.new(
      @adventure,
      observability_session: @observability
    )
    report = checker.check_proposed_response(narrative_content, scene: scene)

    return unless report.issues?

    scene.backstage_events.create!(
      event_type: :consistency_warning,
      details: report.to_backstage_event_details
    )

    Rails.logger.info "[MythicGMService] Consistency warning: #{report.summary}"
  rescue StandardError => e
    Rails.logger.error "[MythicGMService] Consistency check failed: #{e.message}"
  end
end
```

## Best Practices Summary

### 1. Always Pass Sessions for Unified Tracing

```ruby
# Good: Pass session to child services
child_service = ChildService.new(observability_session: session)

# Bad: Let each service create its own session
child_service = ChildService.new # Creates separate session
```

### 2. Use Different Context for Each LLM Call

```ruby
instrument_chat(chat, context: {
  service: 'my_service',
  agent_class: MyAgent,
  step: 'step_1',  # Distinguish different calls
  item_count: items.size
})
```

### 3. Handle Failures Gracefully

```ruby
def orchestrated_operation
  with_observability do |session|
    result1 = step_one
    
    # Non-critical step can fail without breaking main flow
    begin
      result2 = step_two(result1)
    rescue StandardError => e
      Rails.logger.error "Step two failed: #{e.message}"
      # Continue with partial result
    end
    
    result1
  end
end
```

### 4. Use Structured Output for Reliable Data Flow

```ruby
# Define clear schemas for each agent
class Step1Schema < RubyLLM::Schema
  string :output, required: true
end

class Step2Schema < RubyLLM::Schema
  string :refined_output, required: true
end

# Agents guarantee output structure
chat.with_schema(Step1Schema)
response = chat.ask(prompt)
# response.content is always a Hash with :output key
```

### 5. Keep Services Focused

Each service should do ONE thing well:
- `DocumentGeneratorService` - generates documents
- `DocumentRefinerService` - refines documents  
- `DocumentCreationService` - orchestrates both

The orchestrator handles the flow, individual services handle the logic.

## Observability Benefits

With proper session passing, you get:

1. **Single session ID** for the entire operation
2. **All LLM calls** visible in one trace view
3. **Aggregated costs** across all child services
4. **Clear parent-child** relationships in the UI
5. **Easy debugging** - follow the complete flow

The Observ UI will show all traces from all services under one session, making it easy to:
- Track total cost of complex operations
- Debug issues across service boundaries
- Optimize slow or expensive steps
