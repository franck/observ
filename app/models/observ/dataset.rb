# frozen_string_literal: true

module Observ
  class Dataset < ApplicationRecord
    self.table_name = "observ_datasets"

    has_many :items, class_name: "Observ::DatasetItem",
             foreign_key: :dataset_id, dependent: :destroy, inverse_of: :dataset
    has_many :runs, class_name: "Observ::DatasetRun",
             foreign_key: :dataset_id, dependent: :destroy, inverse_of: :dataset

    validates :name, presence: true, uniqueness: true
    validates :agent_class, presence: true
    validate :agent_class_exists, if: -> { agent_class.present? }

    # Returns the agent class constant
    def agent
      agent_class.constantize
    end

    # Returns only active items for running evaluations
    def active_items
      items.active
    end

    # Count helpers for UI
    def items_count
      items.count
    end

    def active_items_count
      items.active.count
    end

    def runs_count
      runs.count
    end

    def last_run
      runs.order(created_at: :desc).first
    end

    private

    def agent_class_exists
      agent_class.constantize
    rescue NameError
      errors.add(:agent_class, "must be a valid agent class")
    end
  end
end
