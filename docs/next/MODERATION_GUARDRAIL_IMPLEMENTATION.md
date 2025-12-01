# Moderation Guardrail Implementation Plan

This document outlines the implementation plan for a `ModerationGuardrailService` that runs content moderation on traces/sessions asynchronously and flags problematic content for the review queue.

## Overview

The Moderation Guardrail system provides:
- **Async moderation** - Background job processing that doesn't block requests
- **Selective application** - Only moderate specific sessions based on criteria
- **Review queue integration** - Flagged content goes to Observ's review queue
- **Observability** - Moderation calls are themselves tracked in Observ

## Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│  Application    │────▶│  ModerationGuardrail │────▶│    Review Queue     │
│  (enqueues job) │     │  Job (async)         │     │  (flagged items)    │
└─────────────────┘     └──────────────────────┘     └─────────────────────┘
                                   │
                                   ▼
                        ┌──────────────────────┐
                        │  ModerationGuardrail │
                        │  Service             │
                        └──────────────────────┘
                                   │
                                   ▼
                        ┌──────────────────────┐
                        │  RubyLLM.moderate()  │
                        └──────────────────────┘
```

## Files to Create

### 1. Service: `app/services/observ/moderation_guardrail_service.rb`

Core service that performs moderation and enqueues for review.

```ruby
# frozen_string_literal: true

module Observ
  class ModerationGuardrailService
    include Observ::Concerns::ObservableService

    # Score thresholds for different actions
    THRESHOLDS = {
      critical: 0.9,  # Auto-flag as critical
      high: 0.7,      # Flag as high priority
      review: 0.5     # Flag for normal review
    }.freeze

    # Categories that always trigger critical review
    CRITICAL_CATEGORIES = %w[
      sexual/minors
      self-harm/intent
      self-harm/instructions
      violence/graphic
    ].freeze

    class Result
      attr_reader :action, :reason, :priority, :details

      def initialize(action:, reason: nil, priority: nil, details: {})
        @action = action
        @reason = reason
        @priority = priority
        @details = details
      end

      def flagged? = action == :flagged
      def skipped? = action == :skipped
      def passed? = action == :passed
    end

    def initialize(observability_session: nil)
      initialize_observability(
        observability_session,
        service_name: 'moderation_guardrail',
        metadata: {}
      )
    end

    # Evaluate a trace for moderation issues
    #
    # @param trace [Observ::Trace] The trace to evaluate
    # @param moderate_input [Boolean] Whether to moderate input content
    # @param moderate_output [Boolean] Whether to moderate output content
    # @return [Result] The evaluation result
    def evaluate_trace(trace, moderate_input: true, moderate_output: true)
      return Result.new(action: :skipped, reason: 'already_in_queue') if trace.in_review_queue?
      return Result.new(action: :skipped, reason: 'already_has_moderation') if has_existing_flags?(trace)

      with_observability do |_session|
        content = extract_trace_content(trace, moderate_input:, moderate_output:)
        return Result.new(action: :skipped, reason: 'no_content') if content.blank?

        perform_moderation(trace, content)
      end
    rescue StandardError => e
      Rails.logger.error "[ModerationGuardrailService] Failed to evaluate trace #{trace.id}: #{e.message}"
      Result.new(action: :skipped, reason: 'error', details: { error: e.message })
    end

    # Evaluate all traces in a session
    #
    # @param session [Observ::Session] The session to evaluate
    # @return [Array<Result>] Results for each trace
    def evaluate_session(session)
      return [] if session.traces.empty?

      session.traces.map do |trace|
        evaluate_trace(trace)
      end
    end

    # Evaluate session-level content (aggregated input/output)
    #
    # @param session [Observ::Session] The session to evaluate
    # @return [Result] The evaluation result
    def evaluate_session_content(session)
      return Result.new(action: :skipped, reason: 'already_in_queue') if session.in_review_queue?

      with_observability do |_session|
        content = extract_session_content(session)
        return Result.new(action: :skipped, reason: 'no_content') if content.blank?

        perform_session_moderation(session, content)
      end
    rescue StandardError => e
      Rails.logger.error "[ModerationGuardrailService] Failed to evaluate session #{session.id}: #{e.message}"
      Result.new(action: :skipped, reason: 'error', details: { error: e.message })
    end

    private

    def has_existing_flags?(trace)
      trace.moderations.any?(&:flagged?)
    end

    def extract_trace_content(trace, moderate_input:, moderate_output:)
      parts = []
      parts << extract_text(trace.input) if moderate_input
      parts << extract_text(trace.output) if moderate_output
      parts.compact.reject(&:blank?).join("\n\n---\n\n")
    end

    def extract_session_content(session)
      session.traces.flat_map do |trace|
        [extract_text(trace.input), extract_text(trace.output)]
      end.compact.reject(&:blank?).join("\n\n---\n\n").truncate(10_000)
    end

    def extract_text(content)
      return nil if content.blank?

      case content
      when String
        content
      when Hash
        # Try common keys for text content
        content['text'] || content['content'] || content['message'] ||
          content[:text] || content[:content] || content[:message] ||
          content.to_json
      else
        content.to_s
      end
    end

    def perform_moderation(trace, content)
      instrument_moderation(context: {
        service: 'moderation_guardrail',
        trace_id: trace.id,
        content_length: content.length
      })

      result = RubyLLM.moderate(content)

      evaluate_and_enqueue(trace, result)
    end

    def perform_session_moderation(session, content)
      instrument_moderation(context: {
        service: 'moderation_guardrail',
        session_id: session.id,
        content_length: content.length
      })

      result = RubyLLM.moderate(content)

      evaluate_and_enqueue_session(session, result)
    end

    def evaluate_and_enqueue(trace, moderation_result)
      priority = determine_priority(moderation_result)

      if priority
        details = build_details(moderation_result)
        trace.enqueue_for_review!(
          reason: 'content_moderation',
          priority: priority,
          details: details
        )

        Result.new(
          action: :flagged,
          priority: priority,
          details: details
        )
      else
        Result.new(action: :passed)
      end
    end

    def evaluate_and_enqueue_session(session, moderation_result)
      priority = determine_priority(moderation_result)

      if priority
        details = build_details(moderation_result)
        session.enqueue_for_review!(
          reason: 'content_moderation',
          priority: priority,
          details: details
        )

        Result.new(
          action: :flagged,
          priority: priority,
          details: details
        )
      else
        Result.new(action: :passed)
      end
    end

    def determine_priority(result)
      # Check for critical categories first
      if (result.flagged_categories & CRITICAL_CATEGORIES).any?
        return :critical
      end

      # Check if explicitly flagged
      if result.flagged?
        max_score = result.category_scores.values.max || 0
        return max_score >= THRESHOLDS[:critical] ? :critical : :high
      end

      # Check score thresholds even if not flagged
      max_score = result.category_scores.values.max || 0

      if max_score >= THRESHOLDS[:high]
        :high
      elsif max_score >= THRESHOLDS[:review]
        :normal
      else
        nil # No action needed
      end
    end

    def build_details(result)
      {
        flagged: result.flagged?,
        flagged_categories: result.flagged_categories,
        highest_category: highest_category(result),
        highest_score: result.category_scores.values.max&.round(4),
        category_scores: result.category_scores.transform_values { |v| v.round(4) }
      }
    end

    def highest_category(result)
      return nil if result.category_scores.empty?

      result.category_scores.max_by { |_, score| score }&.first
    end
  end
end
```

### 2. Job: `app/jobs/observ/moderation_guardrail_job.rb`

Background job for async processing.

```ruby
# frozen_string_literal: true

module Observ
  class ModerationGuardrailJob < ApplicationJob
    queue_as :moderation

    # Retry configuration
    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    # Process a single trace
    #
    # @param trace_id [Integer] ID of the trace to moderate
    # @param options [Hash] Options for moderation
    # @option options [Boolean] :moderate_input Whether to moderate input (default: true)
    # @option options [Boolean] :moderate_output Whether to moderate output (default: true)
    def perform(trace_id: nil, session_id: nil, **options)
      if trace_id
        moderate_trace(trace_id, options)
      elsif session_id
        moderate_session(session_id, options)
      else
        Rails.logger.warn "[ModerationGuardrailJob] No trace_id or session_id provided"
      end
    end

    # Class method to enqueue moderation for traces matching criteria
    #
    # @param scope [ActiveRecord::Relation] Scope of traces to moderate
    # @param sample_percentage [Integer] Percentage of traces to sample (1-100)
    def self.enqueue_for_scope(scope, sample_percentage: 100)
      traces = scope.left_joins(:review_item)
                    .where(observ_review_items: { id: nil })

      if sample_percentage < 100
        sample_size = (traces.count * sample_percentage / 100.0).ceil
        traces = traces.order("RANDOM()").limit(sample_size)
      end

      traces.find_each do |trace|
        perform_later(trace_id: trace.id)
      end
    end

    # Enqueue moderation for user-facing sessions only
    #
    # @param since [Time] Only process sessions created after this time
    def self.enqueue_user_facing(since: 1.hour.ago)
      Observ::Session
        .where(created_at: since..)
        .where("metadata->>'user_facing' = ?", 'true')
        .find_each do |session|
          perform_later(session_id: session.id)
        end
    end

    # Enqueue moderation for specific agent types
    #
    # @param agent_types [Array<String>] Agent types to moderate
    # @param since [Time] Only process sessions created after this time
    def self.enqueue_for_agent_types(agent_types, since: 1.hour.ago)
      Observ::Session
        .where(created_at: since..)
        .where("metadata->>'agent_type' IN (?)", agent_types)
        .find_each do |session|
          perform_later(session_id: session.id)
        end
    end

    private

    def moderate_trace(trace_id, options)
      trace = Observ::Trace.find(trace_id)

      service = ModerationGuardrailService.new
      result = service.evaluate_trace(
        trace,
        moderate_input: options.fetch(:moderate_input, true),
        moderate_output: options.fetch(:moderate_output, true)
      )

      log_result("Trace #{trace_id}", result)
    end

    def moderate_session(session_id, options)
      session = Observ::Session.find(session_id)

      service = ModerationGuardrailService.new

      if options[:aggregate]
        # Moderate aggregated session content
        result = service.evaluate_session_content(session)
        log_result("Session #{session_id} (aggregated)", result)
      else
        # Moderate each trace individually
        results = service.evaluate_session(session)
        flagged_count = results.count(&:flagged?)
        Rails.logger.info "[ModerationGuardrailJob] Session #{session_id}: #{flagged_count}/#{results.size} traces flagged"
      end
    end

    def log_result(identifier, result)
      case result.action
      when :flagged
        Rails.logger.info "[ModerationGuardrailJob] #{identifier} flagged (#{result.priority}): #{result.details[:flagged_categories]}"
      when :skipped
        Rails.logger.debug "[ModerationGuardrailJob] #{identifier} skipped: #{result.reason}"
      when :passed
        Rails.logger.debug "[ModerationGuardrailJob] #{identifier} passed moderation"
      end
    end
  end
end
```

### 3. Spec: `spec/services/observ/moderation_guardrail_service_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Observ::ModerationGuardrailService do
  let(:session) { create(:observ_session) }
  let(:trace) { create(:observ_trace, session: session, input: 'Hello world', output: 'Hi there!') }
  let(:service) { described_class.new }

  let(:safe_moderation_result) do
    double(
      'ModerationResult',
      flagged?: false,
      flagged_categories: [],
      category_scores: { 'hate' => 0.01, 'violence' => 0.02 }
    )
  end

  let(:flagged_moderation_result) do
    double(
      'ModerationResult',
      flagged?: true,
      flagged_categories: ['hate', 'harassment'],
      category_scores: { 'hate' => 0.95, 'harassment' => 0.87, 'violence' => 0.1 }
    )
  end

  let(:high_score_result) do
    double(
      'ModerationResult',
      flagged?: false,
      flagged_categories: [],
      category_scores: { 'hate' => 0.75, 'violence' => 0.2 }
    )
  end

  before do
    allow(RubyLLM).to receive(:moderate).and_return(safe_moderation_result)
  end

  describe '#evaluate_trace' do
    context 'when trace is already in review queue' do
      before do
        trace.enqueue_for_review!(reason: 'test', priority: :normal)
      end

      it 'returns skipped result' do
        result = service.evaluate_trace(trace)
        expect(result.skipped?).to be true
        expect(result.reason).to eq('already_in_queue')
      end
    end

    context 'when trace has no content' do
      let(:trace) { create(:observ_trace, session: session, input: nil, output: nil) }

      it 'returns skipped result' do
        result = service.evaluate_trace(trace)
        expect(result.skipped?).to be true
        expect(result.reason).to eq('no_content')
      end
    end

    context 'when content passes moderation' do
      it 'returns passed result' do
        result = service.evaluate_trace(trace)
        expect(result.passed?).to be true
      end

      it 'does not enqueue for review' do
        expect { service.evaluate_trace(trace) }.not_to change { trace.reload.in_review_queue? }
      end
    end

    context 'when content is flagged' do
      before do
        allow(RubyLLM).to receive(:moderate).and_return(flagged_moderation_result)
      end

      it 'returns flagged result' do
        result = service.evaluate_trace(trace)
        expect(result.flagged?).to be true
      end

      it 'enqueues trace for review' do
        service.evaluate_trace(trace)
        expect(trace.reload.in_review_queue?).to be true
      end

      it 'sets correct priority' do
        result = service.evaluate_trace(trace)
        expect(result.priority).to eq(:high)
      end

      it 'includes flagged categories in details' do
        result = service.evaluate_trace(trace)
        expect(result.details[:flagged_categories]).to eq(['hate', 'harassment'])
      end
    end

    context 'when content has high scores but not flagged' do
      before do
        allow(RubyLLM).to receive(:moderate).and_return(high_score_result)
      end

      it 'returns flagged result with high priority' do
        result = service.evaluate_trace(trace)
        expect(result.flagged?).to be true
        expect(result.priority).to eq(:high)
      end
    end

    context 'with critical categories' do
      let(:critical_result) do
        double(
          'ModerationResult',
          flagged?: true,
          flagged_categories: ['sexual/minors'],
          category_scores: { 'sexual/minors' => 0.99 }
        )
      end

      before do
        allow(RubyLLM).to receive(:moderate).and_return(critical_result)
      end

      it 'sets critical priority' do
        result = service.evaluate_trace(trace)
        expect(result.priority).to eq(:critical)
      end
    end

    context 'with moderate_input and moderate_output options' do
      it 'only moderates input when moderate_output is false' do
        service.evaluate_trace(trace, moderate_input: true, moderate_output: false)
        expect(RubyLLM).to have_received(:moderate).with('Hello world')
      end

      it 'only moderates output when moderate_input is false' do
        service.evaluate_trace(trace, moderate_input: false, moderate_output: true)
        expect(RubyLLM).to have_received(:moderate).with('Hi there!')
      end
    end
  end

  describe '#evaluate_session' do
    let!(:trace1) { create(:observ_trace, session: session, input: 'First message') }
    let!(:trace2) { create(:observ_trace, session: session, input: 'Second message') }

    it 'evaluates all traces in session' do
      results = service.evaluate_session(session)
      expect(results.size).to eq(2)
    end

    it 'returns results for each trace' do
      results = service.evaluate_session(session)
      expect(results.all?(&:passed?)).to be true
    end
  end

  describe '#evaluate_session_content' do
    before do
      create(:observ_trace, session: session, input: 'Message 1', output: 'Response 1')
      create(:observ_trace, session: session, input: 'Message 2', output: 'Response 2')
    end

    it 'moderates aggregated session content' do
      service.evaluate_session_content(session)
      expect(RubyLLM).to have_received(:moderate) do |content|
        expect(content).to include('Message 1')
        expect(content).to include('Response 2')
      end
    end

    context 'when session is already in review queue' do
      before do
        session.enqueue_for_review!(reason: 'test', priority: :normal)
      end

      it 'returns skipped result' do
        result = service.evaluate_session_content(session)
        expect(result.skipped?).to be true
      end
    end
  end
end
```

### 4. Spec: `spec/jobs/observ/moderation_guardrail_job_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Observ::ModerationGuardrailJob, type: :job do
  let(:session) { create(:observ_session) }
  let(:trace) { create(:observ_trace, session: session) }

  let(:safe_result) do
    double(
      'ModerationResult',
      flagged?: false,
      flagged_categories: [],
      category_scores: { 'hate' => 0.01 }
    )
  end

  before do
    allow(RubyLLM).to receive(:moderate).and_return(safe_result)
  end

  describe '#perform' do
    context 'with trace_id' do
      it 'moderates the trace' do
        expect(RubyLLM).to receive(:moderate)
        described_class.perform_now(trace_id: trace.id)
      end
    end

    context 'with session_id' do
      it 'moderates all traces in session' do
        create_list(:observ_trace, 3, session: session)
        expect(RubyLLM).to receive(:moderate).exactly(3).times
        described_class.perform_now(session_id: session.id)
      end
    end

    context 'with session_id and aggregate option' do
      it 'moderates aggregated content' do
        create_list(:observ_trace, 3, session: session)
        expect(RubyLLM).to receive(:moderate).once
        described_class.perform_now(session_id: session.id, aggregate: true)
      end
    end

    context 'with missing record' do
      it 'discards the job' do
        expect {
          described_class.perform_now(trace_id: 999999)
        }.not_to raise_error
      end
    end
  end

  describe '.enqueue_for_scope' do
    before do
      create_list(:observ_trace, 5, session: session)
    end

    it 'enqueues jobs for all traces in scope' do
      expect {
        described_class.enqueue_for_scope(Observ::Trace.all)
      }.to have_enqueued_job(described_class).exactly(5).times
    end

    it 'samples traces when sample_percentage is provided' do
      expect {
        described_class.enqueue_for_scope(Observ::Trace.all, sample_percentage: 50)
      }.to have_enqueued_job(described_class).at_least(2).times
    end

    it 'excludes traces already in review queue' do
      Observ::Trace.first.enqueue_for_review!(reason: 'test', priority: :normal)

      expect {
        described_class.enqueue_for_scope(Observ::Trace.all)
      }.to have_enqueued_job(described_class).exactly(4).times
    end
  end

  describe '.enqueue_user_facing' do
    before do
      create(:observ_session, metadata: { 'user_facing' => 'true' })
      create(:observ_session, metadata: { 'user_facing' => 'false' })
      create(:observ_session, metadata: {})
    end

    it 'only enqueues user-facing sessions' do
      expect {
        described_class.enqueue_user_facing
      }.to have_enqueued_job(described_class).exactly(1).times
    end
  end

  describe '.enqueue_for_agent_types' do
    before do
      create(:observ_session, metadata: { 'agent_type' => 'chat_support' })
      create(:observ_session, metadata: { 'agent_type' => 'internal_tool' })
      create(:observ_session, metadata: { 'agent_type' => 'chat_support' })
    end

    it 'enqueues sessions matching agent types' do
      expect {
        described_class.enqueue_for_agent_types(['chat_support'])
      }.to have_enqueued_job(described_class).exactly(2).times
    end
  end
end
```

## Usage Examples

### 1. Enqueue Moderation After Chat Completion

```ruby
# In your chat controller or service
class ChatService
  def complete_chat(session)
    # ... chat logic ...

    # Enqueue moderation for user-facing chats
    if session.metadata['user_facing']
      Observ::ModerationGuardrailJob.perform_later(session_id: session.id)
    end
  end
end
```

### 2. Scheduled Job for Batch Moderation

```ruby
# config/recurring.yml (solid_queue) or sidekiq-cron
moderation_guardrail:
  class: Observ::ModerationGuardrailJob
  cron: "0 * * * *"  # Every hour
  args:
    method: enqueue_user_facing
    since: 1.hour.ago
```

Or with a custom rake task:

```ruby
# lib/tasks/moderation.rake
namespace :observ do
  namespace :moderation do
    desc "Run moderation on recent user-facing sessions"
    task recent: :environment do
      Observ::ModerationGuardrailJob.enqueue_user_facing(since: 1.hour.ago)
    end

    desc "Run moderation on specific agent types"
    task :agent_types, [:types] => :environment do |_, args|
      types = args[:types].split(',')
      Observ::ModerationGuardrailJob.enqueue_for_agent_types(types)
    end

    desc "Random sample moderation (5%)"
    task sample: :environment do
      Observ::ModerationGuardrailJob.enqueue_for_scope(
        Observ::Trace.where(created_at: 1.day.ago..),
        sample_percentage: 5
      )
    end
  end
end
```

### 3. Inline Moderation in Service

```ruby
# For immediate moderation (blocking)
class ChatModerationService
  def moderate_and_respond(user_message, chat_agent:)
    # Pre-check user input
    guardrail = Observ::ModerationGuardrailService.new
    # ... use for inline checks if needed
  end
end
```

### 4. Session Metadata for Selective Moderation

```ruby
# Mark sessions that should be moderated
session = Observ::Session.create!(
  user_id: current_user.id,
  metadata: {
    agent_type: 'customer_support',
    user_facing: true,
    moderation_required: true
  }
)
```

## Configuration Options

### Thresholds

The service uses configurable thresholds:

| Threshold | Default | Description |
|-----------|---------|-------------|
| `critical` | 0.9 | Scores above this are critical priority |
| `high` | 0.7 | Scores above this are high priority |
| `review` | 0.5 | Scores above this need normal review |

### Critical Categories

These categories always trigger critical review regardless of score:
- `sexual/minors`
- `self-harm/intent`
- `self-harm/instructions`
- `violence/graphic`

## Review Queue Integration

Flagged items appear in the Observ review queue with:

| Field | Value |
|-------|-------|
| `reason` | `content_moderation` |
| `priority` | `:critical`, `:high`, or `:normal` |
| `details.flagged` | Whether content was explicitly flagged |
| `details.flagged_categories` | List of triggered categories |
| `details.highest_category` | Category with highest score |
| `details.highest_score` | Maximum score value |
| `details.category_scores` | All category scores |

## Migration Requirements

No database migrations required - uses existing `review_items` table.

## Dependencies

- `Observ::Concerns::ObservableService` - For instrumenting moderation calls
- `RubyLLM.moderate` - For moderation API calls
- `Observ::ReviewItem` - For review queue integration
- Background job processor (Solid Queue, Sidekiq, etc.)

## Testing Considerations

1. **Mock RubyLLM.moderate** - Avoid real API calls in tests
2. **Test thresholds** - Verify correct priority assignment
3. **Test critical categories** - Ensure critical categories override scores
4. **Test job enqueueing** - Verify selective enqueueing works
5. **Test idempotency** - Ensure already-queued items are skipped

## Future Enhancements

1. **Custom rules per agent type** - Different thresholds for different agents
2. **Webhook notifications** - Notify external systems on critical flags
3. **Rate limiting** - Prevent API overuse in batch operations
4. **Caching** - Cache moderation results for repeated content
5. **Multi-language support** - Language-specific moderation thresholds
