# frozen_string_literal: true

module Observ
  class DatasetRunItem < ApplicationRecord
    self.table_name = "observ_dataset_run_items"

    belongs_to :dataset_run, class_name: "Observ::DatasetRun", inverse_of: :run_items
    belongs_to :dataset_item, class_name: "Observ::DatasetItem", inverse_of: :run_items
    belongs_to :trace, class_name: "Observ::Trace", optional: true
    belongs_to :observation, class_name: "Observ::Observation", optional: true

    validates :dataset_run_id, uniqueness: { scope: :dataset_item_id }

    # Status helpers
    def succeeded?
      trace_id.present? && error.blank?
    end

    def failed?
      error.present?
    end

    def pending?
      trace_id.nil? && error.nil?
    end

    def status
      return :failed if failed?
      return :succeeded if succeeded?
      :pending
    end

    # Access helpers
    def input
      dataset_item.input
    end

    def expected_output
      dataset_item.expected_output
    end

    def actual_output
      trace&.output
    end

    # Comparison helpers
    def output_matches?
      return nil if expected_output.blank? || actual_output.blank?

      normalize_for_comparison(expected_output) == normalize_for_comparison(actual_output)
    end

    # Metrics from trace
    def cost
      trace&.total_cost
    end

    def tokens
      trace&.total_tokens
    end

    def duration_ms
      trace&.duration_ms
    end

    private

    # Normalize output for comparison by parsing JSON strings into comparable structures
    def normalize_for_comparison(output)
      case output
      when Hash
        output.deep_symbolize_keys
      when String
        begin
          parsed = JSON.parse(output)
          parsed.is_a?(Hash) ? parsed.deep_symbolize_keys : parsed
        rescue JSON::ParserError
          output.strip
        end
      else
        output
      end
    end
  end
end
