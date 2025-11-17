# Turbo Stream Race Condition Issue: create.turbo_stream.erb

## Document Information
- **Date**: November 15, 2025
- **Component**: Observ Gem - MessagesController
- **Severity**: Medium - Feature not working as intended
- **Status**: Identified, awaiting fix

## Executive Summary

The `create.turbo_stream.erb` template from the observ gem renders successfully but doesn't display new messages due to a race condition between the HTTP response and asynchronous message creation.

## Issue Description

When a user submits a message through the chat interface, the Turbo Stream response is sent before the messages are created in the database, resulting in an empty or incomplete UI update.

### Expected Behavior
1. User submits a message via the form
2. Controller creates the message synchronously
3. Turbo Stream response updates the UI with the new message
4. Background job processes the AI response

### Actual Behavior
1. User submits a message via the form
2. Controller enqueues background job (does NOT create message)
3. Turbo Stream response renders with no new messages (because they don't exist yet)
4. Background job runs and creates messages in the database
5. UI is not updated via the initial Turbo Stream response

## Technical Analysis

### Request Flow

```
1. POST /observ/chats/:chat_id/messages
   ↓
2. MessagesController#create
   - Calls: ChatResponseJob.perform_later(@chat.id, content)
   - Responds with: create.turbo_stream.erb
   ↓
3. create.turbo_stream.erb renders
   - Queries: @chat.messages.last(2)
   - Problem: Messages don't exist yet!
   ↓
4. HTTP Response sent (200 OK)
   ↓
5. ChatResponseJob executes (AFTER response sent)
   - Line 13: chat.ask(content) creates the user message
   - Creates assistant response
```

### Evidence from Logs

**Controller completes BEFORE messages exist:**
```
Processing by Observ::MessagesController#create as TURBO_STREAM
  Parameters: {"message" => {"content" => "test"}, "chat_id" => "2"}
  Chat Load (0.2ms)
[ActiveJob] Enqueued ChatResponseJob (Job ID: 82562df5...)
  Rendering create.turbo_stream.erb
  Message Load (0.3ms) SELECT "messages".* FROM "messages" 
                       WHERE "messages"."chat_id" = 2 
                       ORDER BY "messages"."created_at" DESC LIMIT 2
  # ← Returns old messages or empty set
  Rendered create.turbo_stream.erb (Duration: 11.2ms)
Completed 200 OK in 30ms

# THEN, later:
[ActiveJob] [ChatResponseJob] Performing ChatResponseJob...
[ActiveJob] Message Create (1.0ms) INSERT INTO "messages" 
            ("role", "user", "content", "test", ...)
```

### Root Cause

**File**: `app/jobs/chat_response_job.rb:13`

```ruby
def perform(chat_id, content)
  chat = Chat.find(chat_id)
  chat.setup_tools
  
  # THIS is where the user message gets created
  # But this runs AFTER the HTTP response is sent
  chat.ask(content) do |chunk|
    # ...
  end
end
```

The `chat.ask(content)` method (from the observ gem's chat functionality) creates the user message as part of the LLM conversation, which happens asynchronously in the background job.

### Template Analysis

**File**: `/observ/app/views/observ/messages/create.turbo_stream.erb`

```erb
<%= turbo_stream.append "messages" do %>
  <% @chat.messages.last(2).each do |message| %>
    <%= render message %>
  <% end %>
<% end %>

<%= turbo_stream.replace "new_message" do %>
  <%= render "observ/messages/form", chat: @chat, message: @chat.messages.build %>
<% end %>
```

The template expects messages to exist when it renders, but they're created after the template has already been rendered and sent to the client.

## Impact

- **User Experience**: Messages don't appear immediately after submission
- **Workaround**: Users must refresh the page to see their submitted messages
- **Scope**: Affects all chat message submissions in the observ gem interface
- **Turbo Infrastructure**: Working correctly - the issue is timing, not configuration

## Verification Status

✅ **Confirmed Working:**
- Turbo Rails is properly installed and configured
- `@hotwired/turbo-rails` is imported in application.js
- Turbo Stream format is being requested and rendered
- Template renders successfully with correct MIME type
- WebSocket connection establishes properly for streaming

❌ **Not Working:**
- Synchronous message creation before HTTP response
- Initial Turbo Stream update showing new messages

## Proposed Solutions

### Solution 1: Create User Message Synchronously (Recommended)

**Modify**: `app/controllers/observ/messages_controller.rb`

```ruby
def create
  return unless content.present?

  # Create user message BEFORE enqueuing job
  user_message = @chat.messages.create!(
    role: :user,
    content: content
  )

  # Now enqueue the job to generate assistant response
  ChatResponseJob.perform_later(@chat.id)

  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to chat_path(@chat) }
  end
end
```

**Modify**: `app/jobs/chat_response_job.rb`

```ruby
def perform(chat_id)
  chat = Chat.find(chat_id)
  chat.setup_tools
  
  # Get the last user message instead of passing content
  user_message = chat.messages.where(role: :user).last
  
  # Generate response based on conversation history
  chat.ask(user_message.content) do |chunk|
    # ... existing streaming logic
  end
end
```

**Pros:**
- User message appears immediately
- Clean separation: controller handles request, job handles AI response
- Maintains existing Turbo Stream functionality

**Cons:**
- Requires changes to both controller and job
- Breaks current API contract (job signature changes)

### Solution 2: Broadcast from Background Job Only

Remove the turbo_stream response from the controller entirely and rely on Action Cable broadcasts from the job.

**Pros:**
- Single source of truth for UI updates
- Already partially implemented with `broadcast_append_chunk`

**Cons:**
- Requires WebSocket connection to be established before form submission
- More complex debugging

### Solution 3: Optimistic UI Update

Use JavaScript to immediately show the message in the UI, then let the job handle persistence.

**Pros:**
- Best perceived performance

**Cons:**
- Most complex implementation
- Requires handling failed submissions

## Recommendations

1. **Immediate**: Implement Solution 1 (synchronous user message creation)
2. **Document**: Update observ gem documentation to explain message creation flow
3. **Test**: Add integration tests to verify Turbo Stream responses contain messages
4. **Monitor**: Check if other controllers in the observ gem have similar race conditions

## Related Files

- `/home/franck/sandbox/src/observ/rails-observ-poc/observ/app/controllers/observ/messages_controller.rb`
- `/home/franck/sandbox/src/observ/rails-observ-poc/observ/app/views/observ/messages/create.turbo_stream.erb`
- `/home/franck/src/tries/mgme/app/jobs/chat_response_job.rb`
- `/home/franck/src/tries/mgme/app/models/chat.rb`

## Additional Notes

The observ gem's chat functionality includes WebSocket-based streaming for AI responses (`broadcast_append_chunk`), which works correctly. The issue only affects the initial form submission response.
