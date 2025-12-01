# User-Facing Chat Service with Automatic Moderation

This guide demonstrates how to build a user-facing chat service that automatically moderates content after each conversation using the `moderate: true` option.

## Overview

When building customer-facing AI applications, you need to:
1. Track all conversations for observability
2. Moderate conversations for policy compliance
3. Flag problematic content for human review

The `moderate: true` option in `ObservableService` automates step 2 and 3 by enqueuing content moderation after each session completes.

## Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│  User Request   │────▶│  ChatService         │────▶│  Response           │
│                 │     │  (moderate: true)    │     │                     │
└─────────────────┘     └──────────────────────┘     └─────────────────────┘
                                   │
                                   │ (async, after session finalization)
                                   ▼
                        ┌──────────────────────┐     ┌─────────────────────┐
                        │  ModerationGuardrail │────▶│  Review Queue       │
                        │  Job                 │     │  (if flagged)       │
                        └──────────────────────┘     └─────────────────────┘
```

## Implementation

### User-Facing Chat Service

```ruby
# app/services/customer_chat_service.rb
class CustomerChatService
  include Observ::Concerns::ObservableService

  def initialize(user:, observability_session: nil, moderate: true)
    @user = user

    # Enable automatic moderation for user-facing conversations
    # When moderate: true, ModerationGuardrailJob runs after session completion
    initialize_observability(
      observability_session,
      service_name: 'customer_chat',
      metadata: {
        user_id: user.id,
        user_facing: true  # Mark as user-facing for batch moderation queries
      },
      moderate: moderate  # Auto-moderate after session completes
    )
  end

  def respond(message)
    with_observability do |session|
      # Create the chat and instrument it
      chat = RubyLLM.chat(model: CustomerSupportAgent.model)
      chat.with_instructions(CustomerSupportAgent.system_prompt)

      instrument_chat(chat, context: {
        service: 'customer_chat',
        agent: 'CustomerSupportAgent',
        user_id: @user.id
      })

      # Get response
      response = chat.ask(message)

      {
        content: response.content,
        session_id: session&.session_id
      }
    end
  rescue StandardError => e
    Rails.logger.error "[CustomerChatService] Error: #{e.message}"
    { error: "Unable to process your request", session_id: nil }
  end
end
```

### Controller Usage

```ruby
# app/controllers/api/chats_controller.rb
class Api::ChatsController < ApplicationController
  def create
    service = CustomerChatService.new(
      user: current_user,
      moderate: true  # Enable automatic moderation
    )

    result = service.respond(chat_params[:message])

    if result[:error]
      render json: { error: result[:error] }, status: :unprocessable_entity
    else
      render json: { response: result[:content] }
    end
  end

  private

  def chat_params
    params.require(:chat).permit(:message)
  end
end
```

## How It Works

1. **User sends message** → `CustomerChatService.new(moderate: true).respond(message)`

2. **Service processes request** → LLM call is made and tracked in observability session

3. **Session finalizes** → `with_observability` completes, session is finalized

4. **Moderation enqueued** → `ModerationGuardrailJob.perform_later(session_id: session.id)` runs automatically

5. **Background moderation** → Job evaluates all traces in the session using `RubyLLM.moderate`

6. **Flagging** → If content exceeds thresholds, it's added to the review queue with appropriate priority

## When Moderation Runs

Moderation only runs when ALL conditions are met:

- `moderate: true` was passed to `initialize_observability`
- The service **owns** the session (created it, not passed in)
- The session exists

This means:
- Parent services can enable moderation for themselves
- Child services using a passed-in session won't duplicate moderation
- Explicitly passing `observability_session: existing_session` skips moderation

### Example: Parent Controls Moderation

```ruby
class ConversationService
  include Observ::Concerns::ObservableService

  def initialize(user:, moderate: true)
    @user = user
    initialize_observability(
      nil,  # Creates new session
      service_name: 'conversation',
      metadata: { user_id: user.id },
      moderate: moderate  # Parent decides on moderation
    )
  end

  def process(message)
    with_observability do |session|
      # Step 1: Translate if needed (uses same session)
      translation_service = TranslationService.new(
        observability_session: session,
        moderate: true  # Ignored - doesn't own session
      )
      translated = translation_service.translate(message)

      # Step 2: Generate response (uses same session)
      chat_service = CustomerChatService.new(
        user: @user,
        observability_session: session,  # Pass session
        moderate: true  # Ignored - doesn't own session
      )
      chat_service.respond(translated)

      # Only ONE moderation job runs (for the parent session)
    end
  end
end
```

## Review Queue Integration

When moderation flags content, it appears in the Observ review queue:

| Field | Value |
|-------|-------|
| `reason` | `content_moderation` |
| `priority` | `:critical`, `:high`, or `:normal` |
| `details.flagged` | Whether content was explicitly flagged |
| `details.flagged_categories` | List of triggered categories |
| `details.highest_score` | Maximum moderation score |

### Priority Levels

| Priority | Condition |
|----------|-----------|
| `:critical` | Critical categories (sexual/minors, self-harm) OR score ≥ 0.9 |
| `:high` | Explicitly flagged OR score ≥ 0.7 |
| `:normal` | Score ≥ 0.5 |

## Conditional Moderation

You can make moderation conditional based on business logic:

```ruby
class ChatService
  include Observ::Concerns::ObservableService

  def initialize(user:)
    @user = user

    # Only moderate for certain user types or conditions
    should_moderate = user.new_user? || user.flagged_before? || user.trust_level < 3

    initialize_observability(
      nil,
      service_name: 'chat',
      metadata: { user_id: user.id },
      moderate: should_moderate
    )
  end
end
```

## Disabling Moderation

### For Development/Testing

```ruby
# In development, you might want to skip moderation
CustomerChatService.new(
  user: current_user,
  moderate: Rails.env.production?
)
```

### For Internal Tools

```ruby
# Internal admin tools might not need moderation
AdminToolService.new(
  admin: current_admin,
  moderate: false  # Trust internal users
)
```

### For Batch Operations

```ruby
# High-volume batch operations might moderate differently
class BatchProcessingService
  include Observ::Concerns::ObservableService

  def initialize
    # Disable automatic moderation for batch jobs
    # Use ModerationGuardrailJob.enqueue_for_scope instead
    initialize_observability(
      nil,
      service_name: 'batch_processing',
      metadata: {},
      moderate: false
    )
  end

  def process_batch(items)
    with_observability do |session|
      items.each { |item| process_item(item) }
    end
  end
end

# Later, moderate a sample
Observ::ModerationGuardrailJob.enqueue_for_scope(
  Observ::Trace.where(created_at: 1.hour.ago..),
  sample_percentage: 10
)
```

## Complete Example: Multi-Turn Conversation

```ruby
# app/services/multi_turn_chat_service.rb
class MultiTurnChatService
  include Observ::Concerns::ObservableService

  def initialize(conversation:, moderate: true)
    @conversation = conversation

    initialize_observability(
      nil,
      service_name: 'multi_turn_chat',
      metadata: {
        conversation_id: conversation.id,
        user_id: conversation.user_id,
        user_facing: true,
        turn_count: conversation.messages.count
      },
      moderate: moderate
    )
  end

  def respond(user_message)
    with_observability do |session|
      # Store user message
      @conversation.messages.create!(role: :user, content: user_message)

      # Build chat with history
      chat = RubyLLM.chat(model: 'gpt-4o-mini')
      chat.with_instructions(system_prompt)

      instrument_chat(chat, context: {
        service: 'multi_turn_chat',
        conversation_id: @conversation.id,
        message_count: @conversation.messages.count
      })

      # Add conversation history
      @conversation.messages.order(:created_at).each do |msg|
        chat.add_message(role: msg.role, content: msg.content)
      end

      # Get response
      response = chat.ask(user_message)
      assistant_content = response.content

      # Store assistant message
      @conversation.messages.create!(role: :assistant, content: assistant_content)

      # Update conversation metadata
      @conversation.update!(
        last_activity_at: Time.current,
        observability_session_id: session&.session_id
      )

      {
        content: assistant_content,
        conversation_id: @conversation.id
      }
    end
    # After this block:
    # 1. Session is finalized
    # 2. ModerationGuardrailJob is enqueued (if moderate: true)
    # 3. All messages in session will be checked
  end

  private

  def system_prompt
    <<~PROMPT
      You are a helpful customer support assistant.
      Be concise, professional, and helpful.
    PROMPT
  end
end
```

### Usage

```ruby
# Controller
def create_message
  conversation = current_user.conversations.find(params[:conversation_id])

  service = MultiTurnChatService.new(
    conversation: conversation,
    moderate: true  # Auto-moderate after each turn
  )

  result = service.respond(params[:message])

  render json: {
    message: result[:content],
    conversation_id: result[:conversation_id]
  }
end
```

## Monitoring Moderation Results

### View Flagged Sessions

```ruby
# In Rails console or admin interface
Observ::ReviewItem
  .where(reason: 'content_moderation')
  .where(status: :pending)
  .order(priority: :desc, created_at: :desc)
  .includes(:reviewable)
  .each do |item|
    puts "#{item.priority}: Session #{item.reviewable.session_id}"
    puts "  Categories: #{item.reason_details['flagged_categories']}"
    puts "  Score: #{item.reason_details['highest_score']}"
  end
```

### Dashboard Query

```ruby
# Sessions flagged in last 24 hours by priority
Observ::ReviewItem
  .where(reason: 'content_moderation')
  .where(created_at: 24.hours.ago..)
  .group(:priority)
  .count
# => { "critical" => 2, "high" => 15, "normal" => 48 }
```

## Best Practices

1. **Always enable for user-facing services** - Use `moderate: true` for any service handling user input

2. **Use session metadata** - Include `user_facing: true` to enable batch moderation queries

3. **Let parents control moderation** - When passing sessions, let the parent service decide

4. **Handle errors gracefully** - Moderation failures are logged but don't break the main flow

5. **Monitor the review queue** - Set up alerts for critical priority items

6. **Use conditional moderation** - Trust levels, user history, or environment can determine moderation

## Checklist

When implementing user-facing services:

- [ ] Include `Observ::Concerns::ObservableService`
- [ ] Add `moderate:` parameter to `initialize`
- [ ] Pass `moderate: true` to `initialize_observability`
- [ ] Include `user_facing: true` in metadata
- [ ] Include `user_id` in metadata for traceability
- [ ] Test with `moderate: false` in development if needed
- [ ] Monitor review queue for flagged content
- [ ] Set up alerts for critical priority flags
