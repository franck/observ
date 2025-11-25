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
    validates :dataset_run_item_id, uniqueness: { scope: [ :name, :source ], message: "already has a score with this name and source" }

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
