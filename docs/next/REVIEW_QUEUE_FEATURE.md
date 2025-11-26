# Review Queue Feature Specification

## Overview

This document details the design and implementation plan for the **Review Queue** feature, which enables manual assessment of production sessions and traces to evaluate agent behavior.

## Problem Statement

Currently, there is no way to:
1. Manually score production traces/sessions without importing them into a dataset
2. Systematically review agent outputs for quality assurance
3. Identify which sessions/traces are most worth reviewing
4. Track review coverage and quality trends over time

## Goals

1. Allow users to **score sessions and traces** directly (thumbs up/down + comment)
2. Provide a **review queue** to systematically work through items needing review
3. Implement **guardrails** that auto-flag interesting items for review (high cost, errors, etc.)
4. Track **review metrics** (coverage, pass rate, trends)

## Non-Goals (for initial implementation)

- Team assignment (assigning reviews to specific people)
- SLA tracking (time-to-review metrics)
- Configurable guardrails via UI (code-based is sufficient)

---

## Feature Design

### Core Concepts

#### 1. Polymorphic Scores

Scores use a **fully polymorphic** design via `scoreable`. This replaces the previous `dataset_run_item_id` + `trace_id` approach with a single, consistent pattern.

```
Score
  - scoreable (polymorphic: Session, Trace, or DatasetRunItem)
  - name (e.g., "manual", "accuracy")
  - value (0.0 to 1.0)
  - data_type (boolean, numeric, categorical)
  - source (manual, programmatic, llm_judge)
  - comment
  - created_by
  - observation_id (optional, for observation-level scores)
```

**Benefits of fully polymorphic approach:**
- Single association pattern for all score types
- Cleaner model with no conditional logic
- Consistent API across Session, Trace, and DatasetRunItem
- Simpler queries and scopes

#### 2. Review Items

A review item represents something queued for human review.

```
ReviewItem
  - reviewable (polymorphic: Session or Trace)
  - status (pending, in_progress, completed, skipped)
  - priority (normal, high, critical)
  - reason (why it was flagged: "high_cost", "error_detected", etc.)
  - reason_details (JSON with context)
  - completed_at
  - completed_by
```

#### 3. Guardrails

Code-based rules that evaluate sessions/traces and auto-flag interesting ones for review.

**Trace Rules:**
| Rule | Priority | Condition |
|------|----------|-----------|
| error_detected | critical | metadata contains error |
| high_cost | high | cost > $0.10 |
| high_latency | normal | duration > 30 seconds |
| no_output | high | output is blank |

**Session Rules:**
| Rule | Priority | Condition |
|------|----------|-----------|
| high_cost | high | total cost > $0.50 |
| short_session | normal | only 1 trace and session ended |

**Random Sampling:**
- Queue a configurable percentage of recent items for quality assurance

---

## User Workflows

### Workflow 1: Ad-hoc Scoring

User is viewing a session or trace and wants to score it:

1. Open session/trace detail page
2. Click "Annotations" drawer (renamed to "Annotations & Scores")
3. See scoring controls (thumbs up/down)
4. Add optional comment
5. Save score

### Workflow 2: Systematic Review

User wants to review flagged items:

1. Navigate to "Review Queue" from main nav
2. See list of pending items sorted by priority
3. Click "Review" on an item
4. See full context (input, output, metrics)
5. Score the item (thumbs up/down + comment)
6. Click "Save & Next" to move to next item
7. Or "Skip" to skip without scoring

### Workflow 3: Review Metrics

User wants to understand review coverage and quality:

1. Navigate to "Review Queue" > "Stats"
2. See metrics:
   - Total pending reviews
   - Reviewed today/this week
   - Pass rate (% positive scores)
   - Pass rate by guardrail reason
   - Review coverage by time period

---

## Architecture

### Data Model

```
┌─────────────────┐
│    Session      │
│  (Reviewable)   │──────┐
│  (Scoreable)    │      │
└────────┬────────┘      │
         │               │
         │ has_one       │ has_many
         ▼               ▼
┌─────────────────┐   ┌─────────────────┐
│  ReviewItem     │   │     Score       │
│                 │   │  (polymorphic)  │
│ - status        │   │                 │
│ - priority      │   │ - name          │
│ - reason        │   │ - value         │
└─────────────────┘   │ - source        │
         ▲            └─────────────────┘
         │                   ▲
         │ has_one           │ has_many
         │                   │
┌────────┴────────┐          │
│     Trace       │──────────┘
│  (Reviewable)   │
│  (Scoreable)    │
└─────────────────┘
         ▲
         │ has_many (as: :scoreable)
         │
┌─────────────────┐
│ DatasetRunItem  │
│  (Scoreable)    │
└─────────────────┘
```

### Service Layer

```
GuardrailService
  - evaluate_trace(trace)     # Apply trace rules
  - evaluate_session(session) # Apply session rules  
  - random_sample(scope:, percentage:)  # Queue random sample
```

---

## Implementation Plan

The implementation is split into three phases to allow incremental delivery and testing.

### Phase 1A: Refactor Score to Polymorphic (Backend Only)

**Goal:** Migrate Score model to fully polymorphic design without changing functionality.

**Rationale:** This is a foundational change that enables all subsequent phases. By doing it first without UI changes, we can verify the data model works correctly with existing dataset scoring.

#### 1A.1 Database Migration

```ruby
# db/migrate/015_refactor_scores_to_polymorphic.rb
class RefactorScoresToPolymorphic < ActiveRecord::Migration[7.0]
  def change
    # Add polymorphic columns
    add_column :observ_scores, :scoreable_type, :string
    add_column :observ_scores, :scoreable_id, :bigint

    # Remove old foreign keys and columns
    remove_foreign_key :observ_scores, :observ_dataset_run_items, column: :dataset_run_item_id
    remove_foreign_key :observ_scores, :observ_traces, column: :trace_id
    remove_column :observ_scores, :dataset_run_item_id, :bigint
    remove_column :observ_scores, :trace_id, :bigint

    # Add indexes
    add_index :observ_scores, [:scoreable_type, :scoreable_id]
    add_index :observ_scores, [:scoreable_type, :scoreable_id, :name, :source],
              unique: true,
              name: "idx_scores_unique_on_scoreable_name_source"
  end
end
```

#### 1A.2 Score Model Updates

```ruby
# app/models/observ/score.rb
module Observ
  class Score < ApplicationRecord
    self.table_name = "observ_scores"

    belongs_to :scoreable, polymorphic: true
    belongs_to :observation, class_name: "Observ::Observation", optional: true

    enum :data_type, { numeric: 0, boolean: 1, categorical: 2 }
    enum :source, { programmatic: 0, manual: 1, llm_judge: 2 }

    validates :name, presence: true
    validates :value, presence: true, numericality: true
    validates :scoreable_id, uniqueness: { 
      scope: [:scoreable_type, :name, :source], 
      message: "already has a score with this name and source" 
    }

    # Scopes
    scope :for_sessions, -> { where(scoreable_type: "Observ::Session") }
    scope :for_traces, -> { where(scoreable_type: "Observ::Trace") }
    scope :for_dataset_run_items, -> { where(scoreable_type: "Observ::DatasetRunItem") }

    # Convenience accessors for polymorphic parent
    def dataset_run_item
      scoreable if scoreable_type == "Observ::DatasetRunItem"
    end

    def trace
      case scoreable_type
      when "Observ::Trace" then scoreable
      when "Observ::DatasetRunItem" then scoreable.trace
      end
    end

    def session
      case scoreable_type
      when "Observ::Session" then scoreable
      when "Observ::Trace" then scoreable.observ_session
      when "Observ::DatasetRunItem" then scoreable.trace&.observ_session
      end
    end

    # Existing helpers
    def passed?
      value >= 0.5
    end

    def failed?
      !passed?
    end

    def display_value
      case data_type
      when "boolean"
        passed? ? "Pass" : "Fail"
      when "categorical"
        string_value.presence || value.to_s
      else
        value.round(2).to_s
      end
    end

    def badge_class
      if boolean?
        passed? ? "observ-badge--success" : "observ-badge--danger"
      else
        value >= 0.7 ? "observ-badge--success" : (value >= 0.4 ? "observ-badge--warning" : "observ-badge--danger")
      end
    end
  end
end
```

#### 1A.3 DatasetRunItem Model Updates

```ruby
# app/models/observ/dataset_run_item.rb
# Change from:
has_many :scores, class_name: "Observ::Score",
         foreign_key: :dataset_run_item_id, dependent: :destroy, inverse_of: :dataset_run_item

# To:
has_many :scores, as: :scoreable, class_name: "Observ::Score", dependent: :destroy
```

#### 1A.4 BaseEvaluator Updates

```ruby
# app/services/observ/evaluators/base_evaluator.rb
# The create_or_update_score method changes from:
def create_or_update_score(run_item, value)
  score = run_item.scores.find_or_initialize_by(name: name, source: :programmatic)
  score.assign_attributes(
    trace: run_item.trace,  # Remove this line
    value: value,
    data_type: data_type,
    comment: options[:comment]
  )
  score.save!
  score
end

# To:
def create_or_update_score(run_item, value)
  score = run_item.scores.find_or_initialize_by(name: name, source: :programmatic)
  score.assign_attributes(
    value: value,
    data_type: data_type,
    comment: options[:comment]
  )
  score.save!
  score
end
```

#### 1A.5 File Summary

| Action | File |
|--------|------|
| Create | `db/migrate/015_refactor_scores_to_polymorphic.rb` |
| Modify | `app/models/observ/score.rb` |
| Modify | `app/models/observ/dataset_run_item.rb` |
| Modify | `app/services/observ/evaluators/base_evaluator.rb` |
| Modify | `spec/models/observ/score_spec.rb` |
| Modify | `spec/factories/observ/observ_scores.rb` |

---

### Phase 1B: Add Scoreable Concern + Direct Scoring UI

**Goal:** Enable scoring Sessions and Traces directly from the UI.

**Depends on:** Phase 1A

#### 1B.1 Scoreable Concern

```ruby
# app/models/concerns/observ/scoreable.rb
module Observ
  module Scoreable
    extend ActiveSupport::Concern

    included do
      has_many :scores, as: :scoreable, class_name: "Observ::Score", dependent: :destroy
    end

    def score_for(name, source: nil)
      scope = scores.where(name: name)
      scope = scope.where(source: source) if source
      scope.order(created_at: :desc).first
    end

    def scored?
      scores.any?
    end

    def manual_score
      score_for("manual", source: :manual)
    end

    def score_summary
      scores.group(:name).average(:value).transform_values { |v| v.round(4) }
    end
  end
end
```

#### 1B.2 Model Includes

```ruby
# app/models/observ/session.rb
include Observ::Scoreable

# app/models/observ/trace.rb
include Observ::Scoreable

# app/models/observ/dataset_run_item.rb
include Observ::Scoreable
# Remove the explicit has_many :scores (now in concern)
```

#### 1B.3 Routes

```ruby
resources :sessions, only: [:index, :show] do
  # ... existing ...
  resources :scores, only: [:create, :destroy], controller: "scores"
end

resources :traces, only: [:index, :show] do
  # ... existing ...
  resources :scores, only: [:create, :destroy], controller: "scores"
end
```

#### 1B.4 ScoresController

```ruby
# app/controllers/observ/scores_controller.rb
module Observ
  class ScoresController < ApplicationController
    before_action :set_scoreable

    def create
      value = parse_score_value(params[:value], params[:data_type])
      
      score = @scoreable.scores.find_or_initialize_by(
        name: params[:name] || "manual",
        source: :manual
      )
      
      score.assign_attributes(
        value: value,
        data_type: params[:data_type] || :boolean,
        comment: params[:comment],
        created_by: params[:created_by]
      )

      if score.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_back(fallback_location: root_path, notice: "Score saved.") }
        end
      else
        respond_to do |format|
          format.turbo_stream { render :create_error, status: :unprocessable_entity }
          format.html { redirect_back(fallback_location: root_path, alert: "Failed to save score.") }
        end
      end
    end

    def destroy
      @score = @scoreable.scores.find(params[:id])
      @score.destroy
      
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.remove("score_#{@score.id}") }
        format.html { redirect_back(fallback_location: root_path, notice: "Score deleted.") }
      end
    end

    private

    def set_scoreable
      if params[:session_id]
        @scoreable = Observ::Session.find(params[:session_id])
      elsif params[:trace_id]
        @scoreable = Observ::Trace.find(params[:trace_id])
      end
    end

    def parse_score_value(value, data_type)
      case data_type&.to_sym
      when :boolean
        value.to_i == 1 ? 1.0 : 0.0
      else
        value.to_f
      end
    end
  end
end
```

#### 1B.5 Views

**Score Form Partial:**
```erb
<%# app/views/observ/scores/_form.html.erb %>
<%= form_with(
  url: scoreable.is_a?(Observ::Session) ? session_scores_path(scoreable) : trace_scores_path(scoreable),
  id: "score-form",
  class: "observ-score-form",
  data: { turbo_frame: "_top" }
) do |form| %>
  <% existing = scoreable.manual_score %>
  
  <div class="observ-form-field">
    <label class="observ-form-label">Score this <%= scoreable.class.name.demodulize.downcase %></label>
    <div class="observ-score-buttons">
      <label class="observ-score-button <%= 'observ-score-button--selected' if existing&.passed? %>">
        <input type="radio" name="value" value="1" <%= "checked" if existing&.passed? %>>
        <span class="observ-score-icon observ-score-icon--pass">&#10003;</span>
        Good
      </label>
      <label class="observ-score-button <%= 'observ-score-button--selected' if existing&.failed? %>">
        <input type="radio" name="value" value="0" <%= "checked" if existing&.failed? %>>
        <span class="observ-score-icon observ-score-icon--fail">&#10005;</span>
        Bad
      </label>
    </div>
    <input type="hidden" name="data_type" value="boolean">
    <input type="hidden" name="name" value="manual">
  </div>

  <div class="observ-form-field">
    <label class="observ-form-label" for="score_comment">Comment (optional)</label>
    <textarea name="comment" id="score_comment" class="observ-form-textarea" rows="2"><%= existing&.comment %></textarea>
  </div>

  <div class="observ-form-actions">
    <%= form.submit "Save Score", class: "observ-button observ-button--primary" %>
  </div>
<% end %>
```

**Update Annotations Drawer:** Add scoring section above annotations in both `traces/annotations_drawer.turbo_stream.erb` and `sessions/annotations_drawer.turbo_stream.erb`.

#### 1B.6 File Summary

| Action | File |
|--------|------|
| Create | `app/models/concerns/observ/scoreable.rb` |
| Create | `app/controllers/observ/scores_controller.rb` |
| Create | `app/views/observ/scores/_form.html.erb` |
| Create | `app/views/observ/scores/create.turbo_stream.erb` |
| Modify | `app/models/observ/session.rb` |
| Modify | `app/models/observ/trace.rb` |
| Modify | `app/models/observ/dataset_run_item.rb` |
| Modify | `config/routes.rb` |
| Modify | `app/views/observ/traces/annotations_drawer.turbo_stream.erb` |
| Modify | `app/views/observ/sessions/annotations_drawer.turbo_stream.erb` |
| Create | `spec/models/concerns/observ/scoreable_spec.rb` |
| Create | `spec/requests/observ/scores_controller_spec.rb` |

---

### Phase 2: Review Queue

**Goal:** Provide a systematic way to review flagged items.

**Depends on:** Phase 1B

#### 2.1 Database Migration

```ruby
# db/migrate/016_create_observ_review_items.rb
class CreateObservReviewItems < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_review_items do |t|
      t.string :reviewable_type, null: false
      t.bigint :reviewable_id, null: false
      
      t.integer :status, default: 0, null: false
      t.integer :priority, default: 0, null: false
      
      t.string :reason
      t.json :reason_details
      
      t.datetime :completed_at
      t.string :completed_by
      
      t.timestamps
      
      t.index [:reviewable_type, :reviewable_id], unique: true
      t.index [:status, :priority, :created_at]
      t.index :status
    end
  end
end
```

#### 2.2 ReviewItem Model

```ruby
# app/models/observ/review_item.rb
module Observ
  class ReviewItem < ApplicationRecord
    self.table_name = "observ_review_items"

    belongs_to :reviewable, polymorphic: true

    enum :status, { pending: 0, in_progress: 1, completed: 2, skipped: 3 }
    enum :priority, { normal: 0, high: 1, critical: 2 }

    validates :reviewable, presence: true
    validates :reviewable_id, uniqueness: { scope: :reviewable_type }

    scope :actionable, -> { where(status: [:pending, :in_progress]) }
    scope :by_priority, -> { order(priority: :desc, created_at: :asc) }
    scope :sessions, -> { where(reviewable_type: "Observ::Session") }
    scope :traces, -> { where(reviewable_type: "Observ::Trace") }

    def complete!(by: nil)
      update!(status: :completed, completed_at: Time.current, completed_by: by)
    end

    def skip!(by: nil)
      update!(status: :skipped, completed_at: Time.current, completed_by: by)
    end

    def start_review!
      update!(status: :in_progress) if pending?
    end

    def priority_badge_class
      case priority
      when "critical" then "observ-badge--danger"
      when "high" then "observ-badge--warning"
      else "observ-badge--secondary"
      end
    end

    def reason_display
      reason&.titleize&.gsub("_", " ") || "Manual"
    end
  end
end
```

#### 2.3 Reviewable Concern

```ruby
# app/models/concerns/observ/reviewable.rb
module Observ
  module Reviewable
    extend ActiveSupport::Concern

    included do
      has_one :review_item, as: :reviewable, class_name: "Observ::ReviewItem", dependent: :destroy
    end

    def enqueue_for_review!(reason:, priority: :normal, details: {})
      review_item || create_review_item!(
        reason: reason.to_s,
        reason_details: details,
        priority: priority,
        status: :pending
      )
    end

    def review_status
      review_item&.status || "not_queued"
    end

    def reviewed?
      review_item&.completed?
    end

    def pending_review?
      review_item&.pending? || review_item&.in_progress?
    end

    def in_review_queue?
      review_item.present?
    end
  end
end
```

#### 2.4 Routes

```ruby
# Add to config/routes.rb
resources :reviews, only: [:index, :show], controller: "review_queue" do
  collection do
    get :sessions
    get :traces
    get :stats
  end
  member do
    post :complete
    post :skip
  end
end
```

#### 2.5 ReviewQueueController

```ruby
# app/controllers/observ/review_queue_controller.rb
module Observ
  class ReviewQueueController < ApplicationController
    before_action :set_review_item, only: [:show, :complete, :skip]

    def index
      @review_items = Observ::ReviewItem
        .actionable
        .by_priority
        .includes(:reviewable)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)
      
      @stats = queue_stats
    end

    def sessions
      @review_items = Observ::ReviewItem
        .sessions
        .actionable
        .by_priority
        .includes(:reviewable)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)
      
      @stats = queue_stats(scope: :sessions)
      render :index
    end

    def traces
      @review_items = Observ::ReviewItem
        .traces
        .actionable
        .by_priority
        .includes(:reviewable)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)
      
      @stats = queue_stats(scope: :traces)
      render :index
    end

    def show
      @review_item.start_review!
      @reviewable = @review_item.reviewable
      @next_item = next_review_item
    end

    def complete
      @review_item.complete!(by: params[:completed_by])
      
      if params[:next] && (next_item = next_review_item)
        redirect_to review_path(next_item), notice: "Review saved. Showing next item."
      else
        redirect_to reviews_path, notice: "Review completed."
      end
    end

    def skip
      @review_item.skip!(by: params[:completed_by])
      
      if next_item = next_review_item
        redirect_to review_path(next_item), notice: "Skipped. Showing next item."
      else
        redirect_to reviews_path, notice: "Item skipped. No more items to review."
      end
    end

    def stats
      @stats = detailed_stats
    end

    private

    def set_review_item
      @review_item = Observ::ReviewItem.find(params[:id])
    end

    def next_review_item
      Observ::ReviewItem
        .actionable
        .by_priority
        .where.not(id: @review_item&.id)
        .first
    end

    def queue_stats(scope: nil)
      base = Observ::ReviewItem
      base = base.send(scope) if scope

      {
        pending: base.pending.count,
        in_progress: base.in_progress.count,
        completed_today: base.completed.where("completed_at >= ?", Time.current.beginning_of_day).count,
        completed_this_week: base.completed.where("completed_at >= ?", Time.current.beginning_of_week).count
      }
    end

    def detailed_stats
      completed = Observ::ReviewItem.completed
      
      {
        total_pending: Observ::ReviewItem.actionable.count,
        total_completed: completed.count,
        completed_today: completed.where("completed_at >= ?", Time.current.beginning_of_day).count,
        completed_this_week: completed.where("completed_at >= ?", Time.current.beginning_of_week).count,
        by_reason: Observ::ReviewItem.group(:reason).count,
        by_priority: Observ::ReviewItem.group(:priority).count,
        pass_rate: calculate_pass_rate
      }
    end

    def calculate_pass_rate
      completed_items = Observ::ReviewItem.completed.includes(:reviewable)
      return nil if completed_items.empty?

      passed = completed_items.count do |item|
        item.reviewable.manual_score&.passed?
      end

      (passed.to_f / completed_items.count * 100).round(1)
    end
  end
end
```

#### 2.6 GuardrailService

```ruby
# app/services/observ/guardrail_service.rb
module Observ
  class GuardrailService
    class << self
      def evaluate_trace(trace)
        trace_rules.each do |rule|
          next unless rule[:condition].call(trace)
          
          trace.enqueue_for_review!(
            reason: rule[:name].to_s,
            priority: rule[:priority],
            details: rule[:details]&.call(trace) || {}
          )
          return # One reason is enough
        end
      end

      def evaluate_session(session)
        session_rules.each do |rule|
          next unless rule[:condition].call(session)
          
          session.enqueue_for_review!(
            reason: rule[:name].to_s,
            priority: rule[:priority],
            details: rule[:details]&.call(session) || {}
          )
          return
        end
      end

      def evaluate_all_recent(since: 1.hour.ago)
        Observ::Trace.where(created_at: since..).find_each do |trace|
          evaluate_trace(trace) unless trace.in_review_queue?
        end

        Observ::Session.where(created_at: since..).find_each do |session|
          evaluate_session(session) unless session.in_review_queue?
        end
      end

      def random_sample(scope:, percentage: 5)
        items = scope.where(created_at: 1.day.ago..)
                     .left_joins(:review_item)
                     .where(observ_review_items: { id: nil })

        sample_size = [(items.count * percentage / 100.0).ceil, 1].max
        
        items.order("RANDOM()").limit(sample_size).find_each do |item|
          item.enqueue_for_review!(reason: "random_sample", priority: :normal)
        end
      end

      private

      def trace_rules
        [
          {
            name: :error_detected,
            priority: :critical,
            condition: ->(t) { t.metadata&.dig("error").present? },
            details: ->(t) { { error: t.metadata["error"] } }
          },
          {
            name: :high_cost,
            priority: :high,
            condition: ->(t) { t.total_cost.present? && t.total_cost > thresholds[:trace_cost] },
            details: ->(t) { { cost: t.total_cost.to_f, threshold: thresholds[:trace_cost] } }
          },
          {
            name: :high_latency,
            priority: :normal,
            condition: ->(t) { t.duration_ms.present? && t.duration_ms > thresholds[:latency_ms] },
            details: ->(t) { { latency_ms: t.duration_ms, threshold: thresholds[:latency_ms] } }
          },
          {
            name: :no_output,
            priority: :high,
            condition: ->(t) { t.output.blank? && t.end_time.present? }
          },
          {
            name: :high_token_count,
            priority: :normal,
            condition: ->(t) { t.total_tokens.present? && t.total_tokens > thresholds[:tokens] },
            details: ->(t) { { tokens: t.total_tokens, threshold: thresholds[:tokens] } }
          }
        ]
      end

      def session_rules
        [
          {
            name: :high_cost,
            priority: :high,
            condition: ->(s) { s.total_cost.present? && s.total_cost > thresholds[:session_cost] },
            details: ->(s) { { cost: s.total_cost.to_f, threshold: thresholds[:session_cost] } }
          },
          {
            name: :short_session,
            priority: :normal,
            condition: ->(s) { s.total_traces_count == 1 && s.end_time.present? },
            details: ->(s) { { trace_count: s.total_traces_count } }
          },
          {
            name: :many_traces,
            priority: :normal,
            condition: ->(s) { s.total_traces_count > thresholds[:max_traces] },
            details: ->(s) { { trace_count: s.total_traces_count, threshold: thresholds[:max_traces] } }
          }
        ]
      end

      def thresholds
        @thresholds ||= {
          trace_cost: 0.10,
          session_cost: 0.50,
          latency_ms: 30_000,
          tokens: 10_000,
          max_traces: 20
        }
      end
    end
  end
end
```

#### 2.7 Navigation Update

Add to main navigation in `app/views/layouts/observ/application.html.erb`:

```erb
<%= link_to reviews_path, class: "observ-nav__link" do %>
  Review Queue
  <% if (pending_count = Observ::ReviewItem.actionable.count) > 0 %>
    <span class="observ-badge observ-badge--danger"><%= pending_count %></span>
  <% end %>
<% end %>
```

#### 2.8 File Summary

| Action | File |
|--------|------|
| Create | `db/migrate/016_create_observ_review_items.rb` |
| Create | `app/models/observ/review_item.rb` |
| Create | `app/models/concerns/observ/reviewable.rb` |
| Create | `app/controllers/observ/review_queue_controller.rb` |
| Create | `app/services/observ/guardrail_service.rb` |
| Create | `app/views/observ/review_queue/index.html.erb` |
| Create | `app/views/observ/review_queue/show.html.erb` |
| Create | `app/views/observ/review_queue/stats.html.erb` |
| Create | `app/views/observ/review_queue/_item.html.erb` |
| Create | `app/views/observ/review_queue/_stats.html.erb` |
| Modify | `app/models/observ/session.rb` |
| Modify | `app/models/observ/trace.rb` |
| Modify | `config/routes.rb` |
| Modify | `app/views/layouts/observ/application.html.erb` |
| Create | `spec/models/observ/review_item_spec.rb` |
| Create | `spec/models/concerns/observ/reviewable_spec.rb` |
| Create | `spec/services/observ/guardrail_service_spec.rb` |
| Create | `spec/requests/observ/review_queue_controller_spec.rb` |

---

## Implementation Checklist

### Phase 1A: Refactor Score to Polymorphic
- [ ] Create migration `015_refactor_scores_to_polymorphic.rb`
- [ ] Update `Score` model with polymorphic `belongs_to :scoreable`
- [ ] Update `DatasetRunItem` to use `has_many :scores, as: :scoreable`
- [ ] Update `BaseEvaluator` to remove `trace:` assignment
- [ ] Update `spec/factories/observ/observ_scores.rb`
- [ ] Update `spec/models/observ/score_spec.rb`
- [ ] Run migrations and verify all existing tests pass

### Phase 1B: Add Scoreable Concern + Direct Scoring UI
- [ ] Create `Scoreable` concern
- [ ] Include `Scoreable` in `Session`, `Trace`, `DatasetRunItem`
- [ ] Add routes for session/trace scores
- [ ] Create `ScoresController`
- [ ] Create score form partial
- [ ] Create turbo_stream response views
- [ ] Update annotations drawer views
- [ ] Create `spec/models/concerns/observ/scoreable_spec.rb`
- [ ] Create `spec/requests/observ/scores_controller_spec.rb`

### Phase 2: Review Queue
- [ ] Create migration `016_create_observ_review_items.rb`
- [ ] Create `ReviewItem` model
- [ ] Create `Reviewable` concern
- [ ] Include `Reviewable` in `Session`, `Trace`
- [ ] Add review routes
- [ ] Create `ReviewQueueController`
- [ ] Create `GuardrailService`
- [ ] Create review queue views
- [ ] Update navigation
- [ ] Create specs for all new code

---

## Future Enhancements

Once the base feature is stable, consider:

1. **Configurable thresholds** - Allow users to set guardrail thresholds in `Observ.config`
2. **Custom guardrails** - Allow defining additional rules via configuration
3. **Review assignment** - Assign reviews to specific team members
4. **Review SLAs** - Track time-to-review for flagged items
5. **Webhook notifications** - Alert when critical items are flagged
6. **Export reviews** - Export review data for analysis
7. **Dashboard integration** - Show review metrics on main dashboard
8. **Auto-archive** - Automatically close old pending reviews
