# frozen_string_literal: true

module Observ
  class DatasetRun < ApplicationRecord
    self.table_name = "observ_dataset_runs"

    belongs_to :dataset, class_name: "Observ::Dataset", inverse_of: :runs
    has_many :run_items, class_name: "Observ::DatasetRunItem",
             foreign_key: :dataset_run_id, dependent: :destroy, inverse_of: :dataset_run
    has_many :items, through: :run_items, source: :dataset_item
    has_many :scores, through: :run_items

    enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }

    validates :name, presence: true, uniqueness: { scope: :dataset_id }

    # Progress tracking
    def progress_percentage
      return 0 if total_items.zero?
      ((completed_items + failed_items).to_f / total_items * 100).round(1)
    end

    def finished?
      completed? || failed?
    end

    def in_progress?
      pending? || running?
    end

    # Update aggregate metrics from run items
    def update_metrics!
      completed = run_items.where.not(trace_id: nil).where(error: nil).count
      failed = run_items.where.not(error: nil).count

      # Calculate cost and tokens from associated traces
      trace_ids = run_items.where.not(trace_id: nil).pluck(:trace_id)
      traces = Observ::Trace.where(id: trace_ids)

      update!(
        completed_items: completed,
        failed_items: failed,
        total_cost: traces.sum(:total_cost) || 0,
        total_tokens: traces.sum(:total_tokens) || 0
      )
    end

    # Initialize run items for all active dataset items
    def initialize_run_items!
      dataset.active_items.find_each do |item|
        run_items.find_or_create_by!(dataset_item: item)
      end
      update!(total_items: run_items.count)
    end

    # Summary helpers for UI
    def success_rate
      return 0 if total_items.zero?
      (completed_items.to_f / total_items * 100).round(1)
    end

    def failure_rate
      return 0 if total_items.zero?
      (failed_items.to_f / total_items * 100).round(1)
    end

    def pending_items_count
      total_items - completed_items - failed_items
    end

    def duration_seconds
      return nil unless finished? && run_items.any?
      first_item = run_items.order(created_at: :asc).first
      last_item = run_items.order(updated_at: :desc).first
      (last_item.updated_at - first_item.created_at).round(1)
    end

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
  end
end
