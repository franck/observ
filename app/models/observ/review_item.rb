# frozen_string_literal: true

module Observ
  class ReviewItem < ApplicationRecord
    self.table_name = "observ_review_items"

    belongs_to :reviewable, polymorphic: true

    enum :status, { pending: 0, in_progress: 1, completed: 2, skipped: 3 }
    enum :priority, { normal: 0, high: 1, critical: 2 }

    validates :reviewable, presence: true
    validates :reviewable_id, uniqueness: { scope: :reviewable_type }

    scope :actionable, -> { where(status: [ :pending, :in_progress ]) }
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

    def reviewable_type_display
      reviewable_type.demodulize
    end
  end
end
