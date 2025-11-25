# frozen_string_literal: true

module Observ
  module DatasetsHelper
    # Returns the appropriate badge class for a run status
    def run_status_badge_class(status)
      case status.to_s
      when "pending"
        "observ-badge--default"
      when "running"
        "observ-badge--info"
      when "completed"
        "observ-badge--success"
      when "failed"
        "observ-badge--danger"
      else
        "observ-badge--default"
      end
    end

    # Returns the appropriate badge class for a run item status
    def run_item_status_badge_class(status)
      case status.to_s
      when "pending"
        "observ-badge--default"
      when "succeeded"
        "observ-badge--success"
      when "failed"
        "observ-badge--danger"
      else
        "observ-badge--default"
      end
    end

    # Formats JSON for display
    def format_json_preview(data, max_length: 100)
      return nil if data.blank?
      text = data.is_a?(Hash) ? data.to_json : data.to_s
      text.length > max_length ? "#{text[0...max_length]}..." : text
    end
  end
end
