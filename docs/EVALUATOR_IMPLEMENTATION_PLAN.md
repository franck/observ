# Evaluator Feature Implementation Plan

## Overview

This document provides the implementation specification for adding the Evaluator feature to the Observ gem. The evaluator system allows users to score LLM outputs from dataset runs using programmatic evaluators, manual review, and (in the future) LLM-as-Judge.

This builds on top of the existing Dataset feature which includes:
- `Dataset` - collection of test cases with an associated agent
- `DatasetItem` - individual test case with input and expected output
- `DatasetRun` - execution of agent against all dataset items
- `DatasetRunItem` - links a dataset item to its execution trace

## Architecture

```
┌─────────────────┐
│  DatasetRun     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ DatasetRunItem  │ ──────► Trace (execution result)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Score(s)     │  Multiple scores per run item
└─────────────────┘
    │
    ├── ExactMatch (programmatic)
    ├── Contains (programmatic)
    ├── Manual (boolean: correct/incorrect)
    └── LLM Judge (future)
```

## Key Decisions

| Decision | Choice |
|----------|--------|
| Evaluator trigger | Manual only (button click), design for future auto-run |
| Evaluator config storage | Dataset-level JSON column (no separate model) |
| LLM-as-Judge | Deferred to Phase 4 |
| Score association | Direct `dataset_run_item_id` foreign key |
| Manual scoring | Boolean only (correct/incorrect) |
| Multi-score support | Yes, unique constraint on `[dataset_run_item_id, name, source]` |
| Existing `output_matches?` | Keep as helper, evaluator creates persistent score |

---

## Phase 1: Score Model & Infrastructure

### Migration: `014_create_observ_scores.rb`

```ruby
# frozen_string_literal: true

class CreateObservScores < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_scores do |t|
      t.references :dataset_run_item, null: false, foreign_key: { to_table: :observ_dataset_run_items }
      t.references :trace, null: false, foreign_key: { to_table: :observ_traces }
      t.references :observation, foreign_key: { to_table: :observ_observations }

      t.string :name, null: false
      t.decimal :value, precision: 10, scale: 4, null: false
      t.integer :data_type, default: 0, null: false
      t.integer :source, default: 0, null: false

      t.text :comment
      t.string :string_value
      t.string :created_by

      t.timestamps

      t.index [:dataset_run_item_id, :name, :source], unique: true, name: "idx_scores_on_run_item_name_source"
      t.index [:trace_id, :name]
      t.index :name
    end
  end
end
```

### Model: `app/models/observ/score.rb`

```ruby
# frozen_string_literal: true

module Observ
  class Score < ApplicationRecord
    self.table_name = "observ_scores"

    belongs_to :dataset_run_item, class_name: "Observ::DatasetRunItem", inverse_of: :scores
    belongs_to :trace, class_name: "Observ::Trace"
    belongs_to :observation, class_name: "Observ::Observation", optional: true

    enum :data_type, { numeric: 0, boolean: 1, categorical: 2 }
    enum :source, { programmatic: 0, manual: 1, llm_judge: 2 }

    validates :name, presence: true
    validates :value, presence: true, numericality: true
    validates :dataset_run_item_id, uniqueness: { scope: [:name, :source], message: "already has a score with this name and source" }

    # Delegations for convenience
    delegate :dataset_run, to: :dataset_run_item
    delegate :dataset_item, to: :dataset_run_item

    # Boolean helpers
    def passed?
      value >= 0.5
    end

    def failed?
      !passed?
    end

    # Display helpers
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

### Update `DatasetRunItem` Model

Add association to `app/models/observ/dataset_run_item.rb`:

```ruby
has_many :scores, class_name: "Observ::Score",
         foreign_key: :dataset_run_item_id, dependent: :destroy, inverse_of: :dataset_run_item

# Score helpers
def score_for(name, source: nil)
  scope = scores.where(name: name)
  scope = scope.where(source: source) if source
  scope.order(created_at: :desc).first
end

def scored?
  scores.any?
end

def passing_scores_count
  scores.where("value >= 0.5").count
end

def failing_scores_count
  scores.where("value < 0.5").count
end
```

### Update `DatasetRun` Model

Add score aggregation methods to `app/models/observ/dataset_run.rb`:

```ruby
has_many :scores, through: :run_items

# Score aggregation
def average_score(name)
  relevant_scores = scores.where(name: name)
  return nil if relevant_scores.empty?
  relevant_scores.average(:value)&.round(4)
end

def score_summary
  scores.group(:name).average(:value).transform_values { |v| v.round(4) }
end

def pass_rate(score_name = nil)
  scope = scores
  scope = scope.where(name: score_name) if score_name
  return nil if scope.empty?
  (scope.where("value >= 0.5").count.to_f / scope.count * 100).round(1)
end

def items_with_scores_count
  run_items.joins(:scores).distinct.count
end

def items_without_scores_count
  total_items - items_with_scores_count
end
```

### Factory: `spec/factories/observ/observ_scores.rb`

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :observ_score, class: "Observ::Score" do
    association :dataset_run_item, factory: :observ_dataset_run_item
    trace { dataset_run_item.trace || association(:observ_trace) }
    name { "accuracy" }
    value { 1.0 }
    data_type { :numeric }
    source { :programmatic }

    trait :passing do
      value { 1.0 }
    end

    trait :failing do
      value { 0.0 }
    end

    trait :boolean do
      data_type { :boolean }
    end

    trait :manual do
      source { :manual }
      data_type { :boolean }
    end

    trait :programmatic do
      source { :programmatic }
    end

    trait :with_comment do
      comment { "Evaluation comment" }
    end
  end
end
```

### Spec: `spec/models/observ/score_spec.rb`

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Score, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:dataset_run_item).class_name("Observ::DatasetRunItem") }
    it { is_expected.to belong_to(:trace).class_name("Observ::Trace") }
    it { is_expected.to belong_to(:observation).class_name("Observ::Observation").optional }
  end

  describe "validations" do
    subject { build(:observ_score) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value) }

    it "validates uniqueness of name scoped to dataset_run_item and source" do
      existing = create(:observ_score, name: "accuracy", source: :programmatic)
      duplicate = build(:observ_score,
        dataset_run_item: existing.dataset_run_item,
        name: "accuracy",
        source: :programmatic
      )
      expect(duplicate).not_to be_valid
    end

    it "allows same name with different source" do
      existing = create(:observ_score, name: "accuracy", source: :programmatic)
      different_source = build(:observ_score,
        dataset_run_item: existing.dataset_run_item,
        name: "accuracy",
        source: :manual
      )
      expect(different_source).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:data_type).with_values(numeric: 0, boolean: 1, categorical: 2) }
    it { is_expected.to define_enum_for(:source).with_values(programmatic: 0, manual: 1, llm_judge: 2) }
  end

  describe "#passed?" do
    it "returns true when value >= 0.5" do
      expect(build(:observ_score, value: 0.5).passed?).to be true
      expect(build(:observ_score, value: 1.0).passed?).to be true
    end

    it "returns false when value < 0.5" do
      expect(build(:observ_score, value: 0.4).passed?).to be false
      expect(build(:observ_score, value: 0.0).passed?).to be false
    end
  end

  describe "#display_value" do
    it "returns Pass/Fail for boolean type" do
      expect(build(:observ_score, :boolean, value: 1.0).display_value).to eq("Pass")
      expect(build(:observ_score, :boolean, value: 0.0).display_value).to eq("Fail")
    end

    it "returns rounded value for numeric type" do
      expect(build(:observ_score, value: 0.8567).display_value).to eq("0.86")
    end

    it "returns string_value for categorical type" do
      score = build(:observ_score, data_type: :categorical, string_value: "good", value: 1.0)
      expect(score.display_value).to eq("good")
    end
  end

  describe "#badge_class" do
    context "when boolean" do
      it "returns success for passing" do
        expect(build(:observ_score, :boolean, value: 1.0).badge_class).to eq("observ-badge--success")
      end

      it "returns danger for failing" do
        expect(build(:observ_score, :boolean, value: 0.0).badge_class).to eq("observ-badge--danger")
      end
    end

    context "when numeric" do
      it "returns success for >= 0.7" do
        expect(build(:observ_score, value: 0.8).badge_class).to eq("observ-badge--success")
      end

      it "returns warning for >= 0.4 and < 0.7" do
        expect(build(:observ_score, value: 0.5).badge_class).to eq("observ-badge--warning")
      end

      it "returns danger for < 0.4" do
        expect(build(:observ_score, value: 0.3).badge_class).to eq("observ-badge--danger")
      end
    end
  end
end
```

---

## Phase 2: Programmatic Evaluators

### Base Evaluator: `app/services/observ/evaluators/base_evaluator.rb`

```ruby
# frozen_string_literal: true

module Observ
  module Evaluators
    class BaseEvaluator
      attr_reader :name, :options

      def initialize(name: nil, **options)
        @name = name || default_name
        @options = options
      end

      # Override in subclasses
      def evaluate(run_item)
        raise NotImplementedError, "Subclasses must implement #evaluate"
      end

      # Creates and persists a score for the run item
      def call(run_item)
        return nil unless run_item.trace.present?

        value = evaluate(run_item)
        return nil if value.nil?

        create_or_update_score(run_item, value)
      end

      protected

      def default_name
        self.class.name.demodulize.underscore.sub(/_evaluator$/, "")
      end

      def data_type
        :numeric
      end

      def create_or_update_score(run_item, value)
        score = run_item.scores.find_or_initialize_by(name: name, source: :programmatic)
        score.assign_attributes(
          trace: run_item.trace,
          value: value,
          data_type: data_type,
          comment: options[:comment]
        )
        score.save!
        score
      end
    end
  end
end
```

### Exact Match Evaluator: `app/services/observ/evaluators/exact_match_evaluator.rb`

```ruby
# frozen_string_literal: true

module Observ
  module Evaluators
    class ExactMatchEvaluator < BaseEvaluator
      def evaluate(run_item)
        return nil if run_item.expected_output.blank?

        run_item.output_matches? ? 1.0 : 0.0
      end

      protected

      def data_type
        :boolean
      end

      def default_name
        "exact_match"
      end
    end
  end
end
```

### Contains Evaluator: `app/services/observ/evaluators/contains_evaluator.rb`

```ruby
# frozen_string_literal: true

module Observ
  module Evaluators
    class ContainsEvaluator < BaseEvaluator
      def evaluate(run_item)
        keywords = options[:keywords] || extract_keywords_from_expected(run_item)
        return nil if keywords.blank?

        output = normalize_output(run_item.actual_output)
        return 0.0 if output.blank?

        matched = keywords.count { |kw| output.downcase.include?(kw.downcase) }
        matched.to_f / keywords.size
      end

      protected

      def default_name
        "contains"
      end

      private

      def extract_keywords_from_expected(run_item)
        expected = run_item.expected_output
        return [] if expected.blank?

        case expected
        when Hash
          expected["keywords"] || expected[:keywords] || []
        when Array
          expected
        when String
          [expected]
        else
          []
        end
      end

      def normalize_output(output)
        case output
        when Hash
          output.to_json
        when String
          output
        else
          output.to_s
        end
      end
    end
  end
end
```

### JSON Structure Evaluator: `app/services/observ/evaluators/json_structure_evaluator.rb`

```ruby
# frozen_string_literal: true

module Observ
  module Evaluators
    class JsonStructureEvaluator < BaseEvaluator
      def evaluate(run_item)
        required_keys = options[:required_keys] || extract_keys_from_expected(run_item)
        return nil if required_keys.blank?

        output = parse_output(run_item.actual_output)
        return 0.0 if output.nil?

        present_keys = required_keys.count { |key| output.key?(key.to_s) || output.key?(key.to_sym) }
        present_keys.to_f / required_keys.size
      end

      protected

      def default_name
        "json_structure"
      end

      private

      def extract_keys_from_expected(run_item)
        expected = run_item.expected_output
        return [] unless expected.is_a?(Hash)

        expected.keys.map(&:to_s)
      end

      def parse_output(output)
        case output
        when Hash
          output
        when String
          JSON.parse(output) rescue nil
        else
          nil
        end
      end
    end
  end
end
```

### Evaluator Runner Service: `app/services/observ/evaluator_runner_service.rb`

```ruby
# frozen_string_literal: true

module Observ
  class EvaluatorRunnerService
    BUILT_IN_EVALUATORS = {
      "exact_match" => Evaluators::ExactMatchEvaluator,
      "contains" => Evaluators::ContainsEvaluator,
      "json_structure" => Evaluators::JsonStructureEvaluator
    }.freeze

    attr_reader :dataset_run, :evaluator_configs

    def initialize(dataset_run, evaluator_configs: nil)
      @dataset_run = dataset_run
      @evaluator_configs = evaluator_configs || default_evaluator_configs
    end

    def call
      return if evaluator_configs.blank?

      dataset_run.run_items.includes(:dataset_item, :trace).find_each do |run_item|
        next unless run_item.succeeded?

        evaluate_item(run_item)
      end

      dataset_run
    end

    def evaluate_item(run_item)
      evaluator_configs.each do |config|
        evaluator = build_evaluator(config)
        next unless evaluator

        evaluator.call(run_item)
      rescue StandardError => e
        Rails.logger.error("Evaluator #{config['type']} failed for run_item #{run_item.id}: #{e.message}")
      end
    end

    private

    def default_evaluator_configs
      # Default to exact_match if no config specified
      [{ "type" => "exact_match" }]
    end

    def build_evaluator(config)
      type = config["type"]
      evaluator_class = BUILT_IN_EVALUATORS[type]

      return nil unless evaluator_class

      options = config.except("type").symbolize_keys
      evaluator_class.new(**options)
    end
  end
end
```

### Spec: `spec/services/observ/evaluator_runner_service_spec.rb`

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::EvaluatorRunnerService do
  let(:dataset) { create(:observ_dataset) }
  let(:dataset_run) { create(:observ_dataset_run, dataset: dataset, status: :completed) }
  let(:dataset_item) { create(:observ_dataset_item, dataset: dataset, input: { query: "test" }, expected_output: "expected") }
  let(:trace) { create(:observ_trace, output: "expected") }
  let!(:run_item) { create(:observ_dataset_run_item, dataset_run: dataset_run, dataset_item: dataset_item, trace: trace) }

  describe "#call" do
    context "with default evaluators" do
      it "runs exact_match evaluator" do
        service = described_class.new(dataset_run)
        service.call

        expect(run_item.scores.count).to eq(1)
        expect(run_item.scores.first.name).to eq("exact_match")
      end
    end

    context "with custom evaluator configs" do
      let(:configs) do
        [
          { "type" => "exact_match" },
          { "type" => "contains", "keywords" => ["expected"] }
        ]
      end

      it "runs all configured evaluators" do
        service = described_class.new(dataset_run, evaluator_configs: configs)
        service.call

        expect(run_item.scores.count).to eq(2)
        expect(run_item.scores.pluck(:name)).to contain_exactly("exact_match", "contains")
      end
    end

    context "when run item has no trace" do
      let!(:pending_run_item) { create(:observ_dataset_run_item, dataset_run: dataset_run, dataset_item: dataset_item, trace: nil) }

      it "skips items without traces" do
        service = described_class.new(dataset_run)
        service.call

        expect(pending_run_item.scores.count).to eq(0)
      end
    end
  end
end
```

### Spec: `spec/services/observ/evaluators/exact_match_evaluator_spec.rb`

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Evaluators::ExactMatchEvaluator do
  let(:dataset_item) { create(:observ_dataset_item, expected_output: "hello world") }
  let(:trace) { create(:observ_trace) }
  let(:run_item) { create(:observ_dataset_run_item, dataset_item: dataset_item, trace: trace) }

  subject(:evaluator) { described_class.new }

  describe "#evaluate" do
    context "when output matches expected" do
      before { allow(run_item).to receive(:output_matches?).and_return(true) }

      it "returns 1.0" do
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end
    end

    context "when output does not match" do
      before { allow(run_item).to receive(:output_matches?).and_return(false) }

      it "returns 0.0" do
        expect(evaluator.evaluate(run_item)).to eq(0.0)
      end
    end

    context "when expected_output is blank" do
      let(:dataset_item) { create(:observ_dataset_item, expected_output: nil) }

      it "returns nil" do
        expect(evaluator.evaluate(run_item)).to be_nil
      end
    end
  end

  describe "#call" do
    before { allow(run_item).to receive(:output_matches?).and_return(true) }

    it "creates a score record" do
      expect { evaluator.call(run_item) }.to change { Observ::Score.count }.by(1)
    end

    it "creates score with correct attributes" do
      score = evaluator.call(run_item)

      expect(score.name).to eq("exact_match")
      expect(score.value).to eq(1.0)
      expect(score.data_type).to eq("boolean")
      expect(score.source).to eq("programmatic")
    end

    it "updates existing score on re-run" do
      evaluator.call(run_item)
      allow(run_item).to receive(:output_matches?).and_return(false)

      expect { evaluator.call(run_item) }.not_to change { Observ::Score.count }
      expect(run_item.scores.first.value).to eq(0.0)
    end
  end
end
```

---

## Phase 3: Score Display & Manual Scoring UI

### Routes Addition

Add to `config/routes.rb`:

```ruby
resources :datasets do
  resources :items, controller: "dataset_items", except: [:show]
  resources :runs, controller: "dataset_runs", only: [:index, :show, :new, :create, :destroy] do
    member do
      post :run_evaluators
    end
    resources :run_items, controller: "dataset_run_items", only: [] do
      member do
        get :details_drawer
        get :score_drawer
        post :score
      end
    end
  end
end
```

### Controller: Update `app/controllers/observ/dataset_runs_controller.rb`

Add action:

```ruby
def run_evaluators
  evaluator_configs = @dataset.metadata&.dig("evaluators") || [{ "type" => "exact_match" }]
  Observ::EvaluatorRunnerService.new(@run, evaluator_configs: evaluator_configs).call

  redirect_to dataset_run_path(@dataset, @run),
    notice: "Evaluators completed. #{@run.items_with_scores_count} items scored."
end
```

### Controller: Update `app/controllers/observ/dataset_run_items_controller.rb`

Add actions:

```ruby
def score_drawer
  @run_item = find_run_item
  render turbo_stream: turbo_stream.replace(
    "drawer-content",
    partial: "observ/dataset_run_items/score_drawer",
    locals: { run_item: @run_item }
  )
end

def score
  @run_item = find_run_item
  value = params[:value].to_i == 1 ? 1.0 : 0.0

  score = @run_item.scores.find_or_initialize_by(name: "manual", source: :manual)
  score.assign_attributes(
    trace: @run_item.trace,
    value: value,
    data_type: :boolean,
    comment: params[:comment],
    created_by: params[:created_by]
  )

  if score.save
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("run-item-#{@run_item.id}-scores", partial: "observ/dataset_run_items/scores_cell", locals: { run_item: @run_item }),
          turbo_stream.replace("drawer-content", partial: "observ/dataset_run_items/score_success", locals: { run_item: @run_item, score: score })
        ]
      end
      format.html { redirect_to dataset_run_path(@dataset, @run), notice: "Score saved." }
    end
  else
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "drawer-content",
          partial: "observ/dataset_run_items/score_drawer",
          locals: { run_item: @run_item, error: score.errors.full_messages.join(", ") }
        )
      end
      format.html { redirect_to dataset_run_path(@dataset, @run), alert: "Failed to save score." }
    end
  end
end

private

def find_run_item
  @dataset = Observ::Dataset.find(params[:dataset_id])
  @run = @dataset.runs.find(params[:run_id])
  @run.run_items.find(params[:id])
end
```

### View: Score drawer partial `app/views/observ/dataset_run_items/_score_drawer.html.erb`

```erb
<div class="observ-drawer__header">
  <h2 class="observ-drawer__title">Score Item</h2>
</div>

<div class="observ-drawer__body">
  <% if local_assigns[:error] %>
    <div class="observ-alert observ-alert--danger"><%= error %></div>
  <% end %>

  <div class="observ-datasets__score-context">
    <h4 class="observ-text--label">Input</h4>
    <pre class="observ-code-block"><%= JSON.pretty_generate(run_item.input) rescue run_item.input %></pre>

    <% if run_item.expected_output.present? %>
      <h4 class="observ-text--label">Expected Output</h4>
      <pre class="observ-code-block"><%= JSON.pretty_generate(run_item.expected_output) rescue run_item.expected_output %></pre>
    <% end %>

    <h4 class="observ-text--label">Actual Output</h4>
    <pre class="observ-code-block"><%= JSON.pretty_generate(run_item.actual_output) rescue run_item.actual_output %></pre>
  </div>

  <% existing_manual = run_item.score_for("manual", source: :manual) %>

  <%= form_with url: score_dataset_run_run_item_path(run_item.dataset_run.dataset, run_item.dataset_run, run_item), method: :post, class: "observ-form" do |f| %>
    <div class="observ-form__group">
      <label class="observ-form__label">Is the output correct?</label>
      <div class="observ-datasets__score-buttons">
        <label class="observ-datasets__score-button <%= existing_manual&.passed? ? 'observ-datasets__score-button--selected' : '' %>">
          <input type="radio" name="value" value="1" <%= "checked" if existing_manual&.passed? %>>
          <span class="observ-datasets__score-icon observ-datasets__score-icon--pass">✓</span>
          Correct
        </label>
        <label class="observ-datasets__score-button <%= existing_manual&.failed? ? 'observ-datasets__score-button--selected' : '' %>">
          <input type="radio" name="value" value="0" <%= "checked" if existing_manual&.failed? %>>
          <span class="observ-datasets__score-icon observ-datasets__score-icon--fail">✗</span>
          Incorrect
        </label>
      </div>
    </div>

    <div class="observ-form__group">
      <label class="observ-form__label" for="comment">Comment (optional)</label>
      <textarea name="comment" id="comment" class="observ-form__textarea" rows="3"><%= existing_manual&.comment %></textarea>
    </div>

    <div class="observ-form__actions">
      <button type="submit" class="observ-button observ-button--primary">Save Score</button>
    </div>
  <% end %>

  <% if run_item.scores.any? %>
    <div class="observ-datasets__existing-scores">
      <h4 class="observ-text--label">Existing Scores</h4>
      <table class="observ-table observ-table--compact">
        <thead>
          <tr>
            <th>Name</th>
            <th>Value</th>
            <th>Source</th>
          </tr>
        </thead>
        <tbody>
          <% run_item.scores.each do |score| %>
            <tr>
              <td><%= score.name %></td>
              <td><span class="observ-badge <%= score.badge_class %>"><%= score.display_value %></span></td>
              <td><%= score.source %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% end %>
</div>
```

### View: Scores cell partial `app/views/observ/dataset_run_items/_scores_cell.html.erb`

```erb
<td class="observ-table__cell" id="run-item-<%= run_item.id %>-scores">
  <% if run_item.scores.any? %>
    <div class="observ-datasets__scores-list">
      <% run_item.scores.limit(3).each do |score| %>
        <span class="observ-badge <%= score.badge_class %> observ-badge--sm" title="<%= score.name %>: <%= score.display_value %>">
          <%= score.name.truncate(10) %>: <%= score.display_value %>
        </span>
      <% end %>
      <% if run_item.scores.count > 3 %>
        <span class="observ-text--muted">+<%= run_item.scores.count - 3 %></span>
      <% end %>
    </div>
  <% else %>
    <span class="observ-text--muted">-</span>
  <% end %>
</td>
```

### View: Update run show page `app/views/observ/dataset_runs/show.html.erb`

Add "Run Evaluators" button to header actions:

```erb
<div class="observ-page-header__actions">
  <%= button_to "Run Evaluators", run_evaluators_dataset_run_path(@dataset, @run),
    method: :post,
    class: "observ-button observ-button--secondary",
    disabled: @run.in_progress? %>
  <%= button_to "Delete Run", dataset_run_path(@dataset, @run),
    method: :delete,
    class: "observ-button observ-button--danger",
    data: { confirm: "Are you sure you want to delete this run?" } %>
</div>
```

Add score summary to the metadata section:

```erb
<% if @run.scores.any? %>
  <div class="observ-datasets__metadata-item">
    <dt class="observ-datasets__metadata-label">Score Summary</dt>
    <dd class="observ-datasets__metadata-value">
      <% @run.score_summary.each do |name, avg| %>
        <span class="observ-badge observ-badge--sm"><%= name %>: <%= (avg * 100).round(1) %>%</span>
      <% end %>
    </dd>
  </div>
  <div class="observ-datasets__metadata-item">
    <dt class="observ-datasets__metadata-label">Items Scored</dt>
    <dd class="observ-datasets__metadata-value"><%= @run.items_with_scores_count %> / <%= @run.total_items %></dd>
  </div>
<% end %>
```

Add scores column to run items table and score button:

```erb
<th class="observ-table__cell">Scores</th>
```

```erb
<%= render "observ/dataset_run_items/scores_cell", run_item: run_item %>
<td class="observ-table__cell observ-table__cell--actions">
  <div class="observ-datasets-table__action-group">
    <%= link_to "Score",
      "#",
      class: "observ-button observ-button--sm",
      data: {
        action: "click->observ--drawer#open",
        drawer_url_param: score_drawer_dataset_run_run_item_path(@dataset, @run, run_item)
      } %>
    <!-- existing buttons -->
  </div>
</td>
```

### CSS: Add to `app/assets/stylesheets/observ/datasets.css`

```css
/* Score buttons */
.observ-datasets__score-buttons {
  display: flex;
  gap: 1rem;
  margin-top: 0.5rem;
}

.observ-datasets__score-button {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1rem 1.5rem;
  border: 2px solid var(--observ-border-color);
  border-radius: var(--observ-radius);
  cursor: pointer;
  transition: all 0.2s ease;
}

.observ-datasets__score-button:hover {
  border-color: var(--observ-primary);
}

.observ-datasets__score-button--selected {
  border-color: var(--observ-primary);
  background: var(--observ-primary-light);
}

.observ-datasets__score-button input[type="radio"] {
  display: none;
}

.observ-datasets__score-icon {
  font-size: 1.25rem;
  font-weight: bold;
}

.observ-datasets__score-icon--pass {
  color: var(--observ-success);
}

.observ-datasets__score-icon--fail {
  color: var(--observ-danger);
}

/* Scores list in table */
.observ-datasets__scores-list {
  display: flex;
  flex-wrap: wrap;
  gap: 0.25rem;
}

/* Score context in drawer */
.observ-datasets__score-context {
  margin-bottom: 1.5rem;
}

.observ-datasets__score-context h4 {
  margin-bottom: 0.5rem;
}

.observ-datasets__score-context pre {
  max-height: 150px;
  overflow-y: auto;
}

/* Existing scores section */
.observ-datasets__existing-scores {
  margin-top: 2rem;
  padding-top: 1.5rem;
  border-top: 1px solid var(--observ-border-color);
}

.observ-datasets__existing-scores h4 {
  margin-bottom: 0.75rem;
}
```

---

## Phase 4: LLM-as-Judge (Future)

### Evaluator: `app/services/observ/evaluators/llm_judge_evaluator.rb`

```ruby
# frozen_string_literal: true

module Observ
  module Evaluators
    class LlmJudgeEvaluator < BaseEvaluator
      DEFAULT_PROMPT = <<~PROMPT
        You are an expert evaluator. Score the following LLM output on a scale of 0-10.

        Input: %{input}

        Expected Output: %{expected_output}

        Actual Output: %{actual_output}

        Criteria: %{criteria}

        Return ONLY a JSON object: {"score": <0-10>, "reasoning": "<explanation>"}
      PROMPT

      def evaluate(run_item)
        prompt = build_prompt(run_item)
        response = call_llm(prompt)
        parse_response(response)
      end

      protected

      def data_type
        :numeric
      end

      def default_name
        "llm_judge"
      end

      private

      def build_prompt(run_item)
        template = options[:prompt_template] || DEFAULT_PROMPT
        criteria = options[:criteria] || ["accuracy", "relevance", "completeness"]

        format(template,
          input: run_item.input.to_json,
          expected_output: run_item.expected_output.to_json,
          actual_output: run_item.actual_output.to_s,
          criteria: criteria.join(", ")
        )
      end

      def call_llm(prompt)
        # Use RubyLLM or configured LLM provider
        model = options[:model] || "gpt-4o-mini"
        # Implementation depends on your LLM setup
        RubyLLM.chat(model: model, messages: [{ role: "user", content: prompt }])
      end

      def parse_response(response)
        content = response.respond_to?(:content) ? response.content : response.to_s
        result = JSON.parse(content)
        result["score"].to_f / 10.0 # Normalize to 0-1
      rescue JSON::ParserError
        nil
      end
    end
  end
end
```

---

## Phase 5: Run Comparison (Future)

### Controller: Add comparison action

```ruby
# In dataset_runs_controller.rb
def compare
  @runs = @dataset.runs.where(id: params[:run_ids]).includes(run_items: :scores)
  @comparison = Observ::RunComparisonService.new(@runs).call
end
```

### Service: `app/services/observ/run_comparison_service.rb`

```ruby
# frozen_string_literal: true

module Observ
  class RunComparisonService
    attr_reader :runs

    def initialize(runs)
      @runs = runs
    end

    def call
      {
        runs: runs.map { |run| run_summary(run) },
        score_comparison: score_comparison,
        item_comparison: item_comparison
      }
    end

    private

    def run_summary(run)
      {
        id: run.id,
        name: run.name,
        created_at: run.created_at,
        total_items: run.total_items,
        completed_items: run.completed_items,
        failed_items: run.failed_items,
        total_cost: run.total_cost,
        total_tokens: run.total_tokens,
        score_summary: run.score_summary,
        pass_rate: run.pass_rate
      }
    end

    def score_comparison
      score_names = runs.flat_map { |r| r.scores.pluck(:name) }.uniq

      score_names.each_with_object({}) do |name, result|
        result[name] = runs.each_with_object({}) do |run, run_scores|
          run_scores[run.id] = {
            average: run.average_score(name),
            pass_rate: run.pass_rate(name)
          }
        end
      end
    end

    def item_comparison
      # Group by dataset_item_id for side-by-side comparison
      item_ids = runs.flat_map { |r| r.run_items.pluck(:dataset_item_id) }.uniq

      item_ids.each_with_object({}) do |item_id, result|
        result[item_id] = runs.each_with_object({}) do |run, run_items|
          run_item = run.run_items.find_by(dataset_item_id: item_id)
          run_items[run.id] = run_item ? {
            status: run_item.status,
            output: run_item.actual_output,
            scores: run_item.scores.pluck(:name, :value).to_h
          } : nil
        end
      end
    end
  end
end
```

---

## Files to Create/Modify

### Phase 1: Score Model

| Action | Path |
|--------|------|
| Create | `db/migrate/014_create_observ_scores.rb` |
| Create | `app/models/observ/score.rb` |
| Modify | `app/models/observ/dataset_run_item.rb` (add association + helpers) |
| Modify | `app/models/observ/dataset_run.rb` (add score aggregation) |
| Create | `spec/factories/observ/observ_scores.rb` |
| Create | `spec/models/observ/score_spec.rb` |

### Phase 2: Programmatic Evaluators

| Action | Path |
|--------|------|
| Create | `app/services/observ/evaluators/base_evaluator.rb` |
| Create | `app/services/observ/evaluators/exact_match_evaluator.rb` |
| Create | `app/services/observ/evaluators/contains_evaluator.rb` |
| Create | `app/services/observ/evaluators/json_structure_evaluator.rb` |
| Create | `app/services/observ/evaluator_runner_service.rb` |
| Create | `spec/services/observ/evaluators/base_evaluator_spec.rb` |
| Create | `spec/services/observ/evaluators/exact_match_evaluator_spec.rb` |
| Create | `spec/services/observ/evaluators/contains_evaluator_spec.rb` |
| Create | `spec/services/observ/evaluators/json_structure_evaluator_spec.rb` |
| Create | `spec/services/observ/evaluator_runner_service_spec.rb` |

### Phase 3: UI & Manual Scoring

| Action | Path |
|--------|------|
| Modify | `config/routes.rb` (add score routes) |
| Modify | `app/controllers/observ/dataset_runs_controller.rb` (add run_evaluators) |
| Modify | `app/controllers/observ/dataset_run_items_controller.rb` (add score actions) |
| Create | `app/views/observ/dataset_run_items/_score_drawer.html.erb` |
| Create | `app/views/observ/dataset_run_items/_scores_cell.html.erb` |
| Create | `app/views/observ/dataset_run_items/_score_success.html.erb` |
| Modify | `app/views/observ/dataset_runs/show.html.erb` (add scores display) |
| Modify | `app/assets/stylesheets/observ/datasets.css` (add score styles) |
| Modify | `app/helpers/observ/datasets_helper.rb` (add score helpers) |

### Phase 4: LLM-as-Judge (Future)

| Action | Path |
|--------|------|
| Create | `app/services/observ/evaluators/llm_judge_evaluator.rb` |
| Create | `spec/services/observ/evaluators/llm_judge_evaluator_spec.rb` |

### Phase 5: Run Comparison (Future)

| Action | Path |
|--------|------|
| Create | `app/services/observ/run_comparison_service.rb` |
| Create | `app/views/observ/dataset_runs/compare.html.erb` |
| Create | `spec/services/observ/run_comparison_service_spec.rb` |

---

## Implementation Order

1. **Phase 1**: Create migration, Score model, associations, factory, specs
2. **Phase 2**: Create evaluator classes and runner service with specs
3. **Phase 3**: Update routes, controllers, views for UI and manual scoring
4. **Phase 4**: Add LLM-as-Judge evaluator (when needed)
5. **Phase 5**: Add run comparison feature (when needed)

Run specs after each phase before proceeding to the next.

---

## Testing Checklist

- [ ] Score model creates with all required fields
- [ ] Score uniqueness constraint works (run_item + name + source)
- [ ] ExactMatchEvaluator creates boolean scores
- [ ] ContainsEvaluator calculates partial matches
- [ ] EvaluatorRunnerService processes all run items
- [ ] Manual scoring creates/updates scores via UI
- [ ] Score summary displays correctly on run page
- [ ] Run evaluators button triggers evaluation
- [ ] Scores display in run items table
- [ ] Score drawer shows input/output context
