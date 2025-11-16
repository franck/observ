module Observ
  module DashboardHelper
    def format_currency(amount)
      return "$0.00" if amount.nil? || amount.zero?
      "$#{sprintf('%.4f', amount)}"
    end

    def format_duration_ms(ms)
      return "0ms" if ms.nil? || ms.zero?
      return "#{ms.round(0)}ms" if ms < 1000
      "#{(ms / 1000.0).round(1)}s"
    end

    def format_duration_s(seconds)
      return "0s" if seconds.nil? || seconds.zero?
      return "#{seconds.round(1)}s" if seconds < 60
      minutes = (seconds / 60).floor
      remaining_seconds = (seconds % 60).round(0)
      "#{minutes}m #{remaining_seconds}s"
    end

    def format_tokens(count)
      return "0" if count.nil? || count.zero?
      return count.to_s if count < 1000
      return "#{(count / 1000.0).round(1)}K" if count < 1_000_000
      "#{(count / 1_000_000.0).round(1)}M"
    end

    def format_number(number)
      return "0" if number.nil? || number.zero?
      number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    def observ_status_badge(status)
      css_class = case status&.downcase
      when "completed", "success"
        "observ-badge--success"
      when "active", "running", "in_progress"
        "observ-badge--info"
      when "failed", "error"
        "observ-badge--danger"
      else
        "observ-badge--warning"
      end

      content_tag(:span, status&.titleize || "Unknown", class: "observ-badge #{css_class}")
    end

    def observ_trend_badge(percentage)
      return content_tag(:span, "0%", class: "observ-trend observ-trend--neutral") if percentage.zero?

      css_class = percentage.positive? ? "observ-trend--positive" : "observ-trend--negative"
      icon = percentage.positive? ? "↑" : "↓"

      content_tag(:span, class: "observ-trend #{css_class}") do
        "#{icon} #{percentage.abs}%"
      end
    end

    def truncate_id(id, length = 8)
      return "" if id.nil?
      id.to_s[0...length]
    end

    def observ_percentage(value)
      "#{value.round(1)}%"
    end

    def observ_timestamp(time)
      return "N/A" if time.nil?
      time.strftime("%Y-%m-%d %H:%M:%S")
    end

    def observ_relative_time(time)
      return "N/A" if time.nil?
      distance_of_time_in_words_to_now(time) + " ago"
    end

    def observ_session_status(session)
      session.end_time.present? ? "completed" : "active"
    end

    def observ_trace_status(trace)
      trace.end_time.present? ? "completed" : "active"
    end

    def observ_model_badge(model)
      return content_tag(:span, "Unknown", class: "observ-model-badge") if model.blank?

      content_tag(:span, model, class: "observ-model-badge")
    end

    def observ_json_preview(json_data, max_length = 100)
      return "" if json_data.nil?

      text = json_data.is_a?(String) ? json_data : json_data.to_json
      truncate(text, length: max_length)
    end

    def format_json_with_newlines(data)
      return "" if data.nil?

      # Convert to JSON with pretty formatting
      json_string = JSON.pretty_generate(data)

      # This regex finds string values in JSON and unescapes newlines within them
      # It preserves the JSON structure while making newlines visible
      json_string.gsub(/: "((?:[^"\\]|\\.)*)"/m) do |match|
        content = $1
        # Unescape the newlines in the string content
        unescaped = content.gsub('\\n', "\n")
                          .gsub('\\t', "\t")
                          .gsub('\\r', "\r")
        ': "' + unescaped + '"'
      end
    end
  end
end
