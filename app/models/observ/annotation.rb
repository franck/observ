# frozen_string_literal: true

module Observ
  class Annotation < ApplicationRecord
    belongs_to :annotatable, polymorphic: true

    validates :content, presence: true

    # Serialize tags as JSON for SQLite compatibility
    serialize :tags, coder: JSON

    scope :recent, -> { order(created_at: :desc) }

    # Ensure tags is always an array
    after_initialize :ensure_tags_array

    private

    def ensure_tags_array
      self.tags ||= []
    end
  end
end
