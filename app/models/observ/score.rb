# frozen_string_literal: true

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
      scope: [ :scoreable_type, :name, :source ],
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

    # Delegations for backward compatibility with dataset scoring
    def dataset_run
      dataset_run_item&.dataset_run
    end

    def dataset_item
      dataset_run_item&.dataset_item
    end

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
