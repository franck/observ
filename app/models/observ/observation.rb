# frozen_string_literal: true

module Observ
  class Observation < ApplicationRecord
    self.table_name = "observ_observations"
    self.inheritance_column = :type

    belongs_to :trace, class_name: "Observ::Trace", foreign_key: :observ_trace_id, inverse_of: :observations

    validates :observation_id, presence: true, uniqueness: true
    validates :start_time, presence: true
    validates :type, presence: true, inclusion: {
    in: %w[Observ::Generation Observ::Span Observ::Embedding Observ::ImageGeneration Observ::Transcription]
  }

    after_save :update_trace_metrics, if: :saved_change_to_cost_or_usage?

    def finalize(status_message: nil)
      update!(
        end_time: Time.current,
        status_message: status_message
      )
    end

    def duration_ms
      return nil unless end_time
      ((end_time - start_time) * 1000).round(2)
    end

    private

    def saved_change_to_cost_or_usage?
      saved_change_to_cost_usd? || saved_change_to_usage?
    end

    def update_trace_metrics
      trace&.update_aggregated_metrics
    end
  end
end
