# frozen_string_literal: true

module Observ
  module ReviewsHelper
    # Returns the appropriate badge class for a priority level
    def priority_badge_class(priority)
      case priority.to_s
      when "critical"
        "observ-badge--danger"
      when "high"
        "observ-badge--warning"
      else
        "observ-badge--secondary"
      end
    end

    # Returns the appropriate badge class for a review status
    def review_status_badge_class(status)
      case status.to_s
      when "pending"
        "observ-badge--default"
      when "in_progress"
        "observ-badge--info"
      when "completed"
        "observ-badge--success"
      when "skipped"
        "observ-badge--secondary"
      else
        "observ-badge--default"
      end
    end
  end
end
