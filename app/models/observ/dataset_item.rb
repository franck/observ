# frozen_string_literal: true

module Observ
  class DatasetItem < ApplicationRecord
    self.table_name = "observ_dataset_items"

    belongs_to :dataset, class_name: "Observ::Dataset", inverse_of: :items
    belongs_to :source_trace, class_name: "Observ::Trace", optional: true
    has_many :run_items, class_name: "Observ::DatasetRunItem",
             foreign_key: :dataset_item_id, dependent: :destroy, inverse_of: :dataset_item

    enum :status, { active: 0, archived: 1 }

    validates :input, presence: true

    scope :active, -> { where(status: :active) }
    scope :archived, -> { where(status: :archived) }

    # Preview helpers for UI display
    def input_preview(max_length: 100)
      return nil if input.blank?
      text = input.is_a?(Hash) ? input.to_json : input.to_s
      text.length > max_length ? "#{text[0...max_length]}..." : text
    end

    def expected_output_preview(max_length: 100)
      return nil if expected_output.blank?
      text = expected_output.is_a?(Hash) ? expected_output.to_json : expected_output.to_s
      text.length > max_length ? "#{text[0...max_length]}..." : text
    end

    # Check if this item has been run
    def run_count
      run_items.count
    end

    def last_run_item
      run_items.order(created_at: :desc).first
    end
  end
end
