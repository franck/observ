# Content Moderation Service

This guide demonstrates patterns for building services that use RubyLLM's content moderation capabilities with full observability.

## Overview

RubyLLM provides content moderation via `RubyLLM.moderate()`. Observ can instrument these calls to track:
- Flagged content detection
- Category classifications (hate, harassment, violence, etc.)
- Category scores for each moderation category
- Model used (omni-moderation-latest, text-moderation-stable, etc.)

Note: Moderation API calls are typically free, so cost tracking shows $0.00.

## Pattern 1: Simple Moderation Service

A straightforward service that checks content for policy violations.

### Service Implementation

```ruby
# app/services/content_moderation_service.rb
class ContentModerationService
  include Observ::Concerns::ObservableService

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'content_moderation',
      metadata: {}
    )
  end

  def check(content)
    with_observability do |_session|
      # Instrument moderation for observability
      instrument_moderation(context: {
        service: 'content_moderation',
        content_length: content&.length || 0
      })

      # Perform moderation
      result = RubyLLM.moderate(content)

      {
        safe: !result.flagged?,
        flagged: result.flagged?,
        flagged_categories: result.flagged_categories,
        categories: result.categories,
        scores: result.category_scores
      }
    end
  rescue StandardError => e
    Rails.logger.error "[ContentModerationService] Failed: #{e.message}"
    { safe: false, error: e.message }
  end

  # Check if content is safe (convenience method)
  def safe?(content)
    result = check(content)
    result[:safe] && !result[:error]
  end
end
```

### Usage

```ruby
# Basic usage
service = ContentModerationService.new
result = service.check("Hello, how are you today?")

if result[:safe]
  puts "Content is safe"
else
  puts "Content flagged for: #{result[:flagged_categories].join(', ')}"
end

# Quick safety check
if service.safe?("Some user input")
  process_content
else
  reject_content
end
```

## Pattern 2: User Input Guardrail Service

A service that moderates user input before processing, commonly used as a guardrail.

### Service Implementation

```ruby
# app/services/input_guardrail_service.rb
class InputGuardrailService
  include Observ::Concerns::ObservableService

  # Categories that should block content
  BLOCKING_CATEGORIES = %w[
    hate
    harassment
    self-harm
    sexual/minors
    violence/graphic
  ].freeze

  # Categories that trigger a warning but don't block
  WARNING_CATEGORIES = %w[
    sexual
    violence
    harassment/threatening
  ].freeze

  # Score threshold for blocking (even if not officially flagged)
  SCORE_THRESHOLD = 0.7

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'input_guardrail',
      metadata: {}
    )
  end

  def validate(user_input, context: {})
    with_observability do |_session|
      return allow_result if user_input.blank?

      instrument_moderation(context: {
        service: 'input_guardrail',
        input_length: user_input.length,
        **context
      })

      result = RubyLLM.moderate(user_input)

      evaluate_result(result, user_input)
    end
  rescue StandardError => e
    Rails.logger.error "[InputGuardrailService] Failed: #{e.message}"
    # Fail closed: block on error
    block_result("Moderation check failed", error: e.message)
  end

  private

  def evaluate_result(result, input)
    # Check for blocking categories
    blocking = result.flagged_categories & BLOCKING_CATEGORIES
    if blocking.any?
      return block_result(
        "Content violates policy",
        categories: blocking,
        scores: result.category_scores.slice(*blocking)
      )
    end

    # Check for high scores even if not officially flagged
    high_scores = result.category_scores.select { |_, score| score >= SCORE_THRESHOLD }
    blocking_high_scores = high_scores.keys & BLOCKING_CATEGORIES
    if blocking_high_scores.any?
      return block_result(
        "Content likely violates policy",
        categories: blocking_high_scores,
        scores: high_scores.slice(*blocking_high_scores)
      )
    end

    # Check for warning categories
    warnings = result.flagged_categories & WARNING_CATEGORIES
    if warnings.any?
      return warn_result(
        "Content may be sensitive",
        categories: warnings,
        scores: result.category_scores.slice(*warnings)
      )
    end

    allow_result
  end

  def allow_result
    { allowed: true, action: :allow }
  end

  def warn_result(reason, categories:, scores:)
    {
      allowed: true,
      action: :warn,
      reason: reason,
      categories: categories,
      scores: scores
    }
  end

  def block_result(reason, categories: [], scores: {}, error: nil)
    {
      allowed: false,
      action: :block,
      reason: reason,
      categories: categories,
      scores: scores,
      error: error
    }.compact
  end
end
```

### Usage

```ruby
service = InputGuardrailService.new

# Validate user input before processing
result = service.validate(params[:message], context: { user_id: current_user.id })

case result[:action]
when :allow
  process_message(params[:message])
when :warn
  log_warning(result)
  process_message(params[:message])
when :block
  render json: { error: "Your message couldn't be processed" }, status: :unprocessable_entity
end
```

## Pattern 3: Pre-LLM Moderation (Chat Guardrail)

A service that moderates user messages before sending them to an LLM.

```ruby
# app/services/chat_moderation_service.rb
class ChatModerationService
  include Observ::Concerns::ObservableService

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'chat_moderation',
      metadata: {}
    )
  end

  def moderate_and_respond(user_message, chat_agent:)
    with_observability do |_session|
      # Step 1: Moderate user input
      moderation = moderate_input(user_message)

      if moderation[:blocked]
        return blocked_response(moderation)
      end

      # Step 2: Process with LLM (only if moderation passed)
      llm_response = call_llm(user_message, chat_agent)

      # Step 3: Optionally moderate LLM output
      output_moderation = moderate_output(llm_response)

      build_response(llm_response, moderation, output_moderation)
    end
  rescue StandardError => e
    Rails.logger.error "[ChatModerationService] Failed: #{e.message}"
    error_response(e.message)
  end

  private

  # Step 1: Moderate user input
  def moderate_input(message)
    instrument_moderation(context: {
      service: 'chat_moderation',
      step: 'input_moderation'
    })

    result = RubyLLM.moderate(message)

    {
      blocked: result.flagged?,
      flagged_categories: result.flagged_categories,
      scores: result.category_scores,
      highest_category: highest_score_category(result.category_scores)
    }
  end

  # Step 2: Call LLM
  def call_llm(message, chat_agent)
    chat = RubyLLM.chat(model: chat_agent.model)
    chat.with_instructions(chat_agent.system_prompt)

    instrument_chat(chat, context: {
      service: 'chat_moderation',
      step: 'llm_response'
    })

    response = chat.ask(message)
    response.content
  end

  # Step 3: Moderate LLM output (optional but recommended)
  def moderate_output(llm_response)
    instrument_moderation(context: {
      service: 'chat_moderation',
      step: 'output_moderation'
    })

    result = RubyLLM.moderate(llm_response)

    {
      flagged: result.flagged?,
      flagged_categories: result.flagged_categories
    }
  end

  def highest_score_category(scores)
    return nil if scores.empty?

    scores.max_by { |_, score| score }&.first
  end

  def build_response(llm_response, input_mod, output_mod)
    response = {
      content: llm_response,
      moderation: {
        input_checked: true,
        output_checked: true,
        output_flagged: output_mod[:flagged]
      }
    }

    # If output was flagged, provide a safe alternative
    if output_mod[:flagged]
      response[:content] = "I apologize, but I cannot provide that response."
      response[:moderation][:output_replaced] = true
    end

    response
  end

  def blocked_response(moderation)
    {
      content: nil,
      blocked: true,
      reason: "Your message could not be processed due to content policy.",
      flagged_categories: moderation[:flagged_categories]
    }
  end

  def error_response(message)
    {
      content: nil,
      error: true,
      reason: "An error occurred processing your message."
    }
  end
end
```

### Usage

```ruby
service = ChatModerationService.new
response = service.moderate_and_respond(
  params[:message],
  chat_agent: CustomerSupportAgent
)

if response[:blocked]
  render json: { error: response[:reason] }, status: :unprocessable_entity
elsif response[:error]
  render json: { error: response[:reason] }, status: :internal_server_error
else
  render json: { response: response[:content] }
end
```

## Pattern 4: Batch Content Moderation

A service for moderating multiple pieces of content efficiently.

```ruby
# app/services/batch_moderation_service.rb
class BatchModerationService
  include Observ::Concerns::ObservableService

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'batch_moderation',
      metadata: {}
    )
  end

  def moderate_batch(contents, fail_fast: false)
    with_observability do |_session|
      results = []

      contents.each_with_index do |content, index|
        result = moderate_single(content, index)
        results << result

        # Stop on first failure if fail_fast is enabled
        if fail_fast && result[:flagged]
          break
        end
      end

      {
        total: contents.size,
        processed: results.size,
        flagged_count: results.count { |r| r[:flagged] },
        all_safe: results.none? { |r| r[:flagged] },
        results: results
      }
    end
  rescue StandardError => e
    Rails.logger.error "[BatchModerationService] Failed: #{e.message}"
    { error: e.message, results: [] }
  end

  # Moderate a collection of records
  def moderate_records(records, content_method:, fail_fast: false)
    with_observability do |_session|
      results = []

      records.each do |record|
        content = record.public_send(content_method)
        result = moderate_single(content, record.id)
        result[:record_id] = record.id

        results << result

        if fail_fast && result[:flagged]
          break
        end
      end

      {
        total: records.size,
        processed: results.size,
        flagged_count: results.count { |r| r[:flagged] },
        flagged_ids: results.select { |r| r[:flagged] }.map { |r| r[:record_id] },
        results: results
      }
    end
  end

  private

  def moderate_single(content, identifier)
    instrument_moderation(context: {
      service: 'batch_moderation',
      item_index: identifier
    })

    result = RubyLLM.moderate(content)

    {
      index: identifier,
      flagged: result.flagged?,
      flagged_categories: result.flagged_categories,
      highest_score: result.category_scores.values.max || 0
    }
  rescue StandardError => e
    {
      index: identifier,
      error: e.message,
      flagged: true # Fail closed
    }
  end
end
```

### Usage

```ruby
service = BatchModerationService.new

# Moderate array of strings
contents = ["Hello world", "Some content", "More content"]
result = service.moderate_batch(contents)

puts "All safe: #{result[:all_safe]}"
puts "Flagged: #{result[:flagged_count]} / #{result[:total]}"

# Moderate ActiveRecord collection
comments = Comment.pending_review.limit(100)
result = service.moderate_records(comments, content_method: :body)

# Flag problematic comments
Comment.where(id: result[:flagged_ids]).update_all(flagged: true)
```

## Pattern 5: UGC (User Generated Content) Pipeline

A complete pipeline for moderating user-generated content before publishing.

```ruby
# app/services/ugc_moderation_pipeline.rb
class UgcModerationPipeline
  include Observ::Concerns::ObservableService

  MODERATION_THRESHOLDS = {
    auto_approve: 0.1,   # Below this, auto-approve
    manual_review: 0.5,  # Between auto_approve and this, needs review
    auto_reject: 0.8     # Above this, auto-reject
  }.freeze

  def initialize(observability_session: nil)
    initialize_observability(
      observability_session,
      service_name: 'ugc_pipeline',
      metadata: {}
    )
  end

  def process(content, metadata: {})
    with_observability do |_session|
      # Step 1: Quick moderation check
      moderation = perform_moderation(content, metadata)

      # Step 2: Determine action based on scores
      decision = make_decision(moderation)

      # Step 3: Log and return result
      build_result(content, moderation, decision)
    end
  rescue StandardError => e
    Rails.logger.error "[UgcModerationPipeline] Failed: #{e.message}"
    # Fail safe: require manual review on error
    {
      action: :manual_review,
      reason: "Moderation check failed: #{e.message}",
      error: true
    }
  end

  private

  def perform_moderation(content, metadata)
    instrument_moderation(context: {
      service: 'ugc_pipeline',
      content_type: metadata[:content_type],
      user_id: metadata[:user_id]
    })

    result = RubyLLM.moderate(content)

    {
      flagged: result.flagged?,
      flagged_categories: result.flagged_categories,
      categories: result.categories,
      scores: result.category_scores,
      max_score: result.category_scores.values.max || 0,
      highest_category: result.category_scores.max_by { |_, v| v }&.first
    }
  end

  def make_decision(moderation)
    max_score = moderation[:max_score]

    if moderation[:flagged]
      # Explicitly flagged content
      if max_score >= MODERATION_THRESHOLDS[:auto_reject]
        :auto_reject
      else
        :manual_review
      end
    elsif max_score <= MODERATION_THRESHOLDS[:auto_approve]
      :auto_approve
    elsif max_score <= MODERATION_THRESHOLDS[:manual_review]
      :auto_approve # Low risk, approve
    else
      :manual_review # High scores but not flagged, review
    end
  end

  def build_result(content, moderation, decision)
    {
      action: decision,
      approved: decision == :auto_approve,
      rejected: decision == :auto_reject,
      needs_review: decision == :manual_review,
      moderation: {
        flagged: moderation[:flagged],
        flagged_categories: moderation[:flagged_categories],
        max_score: moderation[:max_score],
        highest_category: moderation[:highest_category]
      },
      content_preview: content&.truncate(100)
    }
  end
end
```

### Usage

```ruby
pipeline = UgcModerationPipeline.new

# Process user submission
result = pipeline.process(
  params[:content],
  metadata: {
    content_type: 'comment',
    user_id: current_user.id
  }
)

case result[:action]
when :auto_approve
  @comment.update!(status: :published)
when :auto_reject
  @comment.update!(status: :rejected, rejection_reason: result[:moderation][:highest_category])
  notify_user_of_rejection(@comment)
when :manual_review
  @comment.update!(status: :pending_review)
  notify_moderators(@comment, result[:moderation])
end
```

## Observability Benefits

When using `instrument_moderation`, Observ captures:

| Metric | Description |
|--------|-------------|
| `flagged` | Whether content was flagged |
| `categories` | All category classifications (true/false) |
| `category_scores` | Confidence scores for each category (0.0-1.0) |
| `flagged_categories` | List of categories that triggered flagging |
| `model` | Moderation model used |
| `cost_usd` | Always $0.00 (moderation is typically free) |

### Moderation Categories

OpenAI's moderation API checks for these categories:

| Category | Description |
|----------|-------------|
| `hate` | Hateful content targeting protected groups |
| `hate/threatening` | Hateful content with threats of violence |
| `harassment` | Harassing content |
| `harassment/threatening` | Harassment with threats |
| `self-harm` | Content promoting self-harm |
| `self-harm/intent` | Expression of intent to self-harm |
| `self-harm/instructions` | Instructions for self-harm |
| `sexual` | Sexual content |
| `sexual/minors` | Sexual content involving minors |
| `violence` | Violent content |
| `violence/graphic` | Graphic violence |

## Best Practices

### 1. Always Instrument Moderation

```ruby
# Good: Instrument before calling moderate
instrument_moderation(context: { operation: 'user_input_check' })
result = RubyLLM.moderate(content)

# Bad: No observability
result = RubyLLM.moderate(content)
```

### 2. Fail Closed on Errors

```ruby
def moderate_safely(content)
  result = RubyLLM.moderate(content)
  result.flagged?
rescue StandardError => e
  Rails.logger.error "Moderation failed: #{e.message}"
  true # Assume flagged on error (fail closed)
end
```

### 3. Use Score Thresholds for Nuanced Decisions

```ruby
# Don't just check flagged? - use scores for graduated responses
scores = result.category_scores

if scores['hate'] > 0.9
  hard_block
elsif scores['hate'] > 0.7
  soft_block_with_review
elsif scores['hate'] > 0.4
  log_and_monitor
end
```

### 4. Moderate Both Input and Output

```ruby
with_observability do |session|
  # Moderate user input
  instrument_moderation(context: { step: 'input' })
  input_check = RubyLLM.moderate(user_message)
  return blocked_response if input_check.flagged?

  # Call LLM
  response = chat.ask(user_message)

  # Moderate LLM output
  instrument_moderation(context: { step: 'output' })
  output_check = RubyLLM.moderate(response.content)

  if output_check.flagged?
    return safe_fallback_response
  end

  response
end
```

### 5. Include Contextual Metadata

```ruby
instrument_moderation(context: {
  service: 'comment_moderation',
  user_id: user.id,
  content_type: 'comment',
  parent_id: parent_comment&.id,
  is_reply: parent_comment.present?
})
```

### 6. Handle Batch Operations Efficiently

```ruby
# Process in batches to avoid overwhelming the API
contents.each_slice(10) do |batch|
  batch.each do |content|
    instrument_moderation(context: { batch: true })
    RubyLLM.moderate(content)
  end
  sleep(0.1) # Small delay between batches
end
```

## Checklist

When building a moderation service:

- [ ] Include `Observ::Concerns::ObservableService`
- [ ] Call `initialize_observability` in constructor
- [ ] Use `instrument_moderation` before `RubyLLM.moderate`
- [ ] Include meaningful context (service name, step, user_id)
- [ ] Fail closed on errors (assume unsafe if moderation fails)
- [ ] Consider both flagged status AND score thresholds
- [ ] Moderate both user input AND LLM output when applicable
- [ ] Define clear blocking vs warning categories
- [ ] Provide user-friendly error messages (don't expose internal details)
- [ ] Log flagged content for review and model improvement
