# frozen_string_literal: true

module Observ
  class TraceTextFormatter
    SEPARATOR = "=" * 80
    SUBSEPARATOR = "-" * 80
    INDENT = "  "
    MAX_CONTENT_LENGTH = 10_000

    attr_reader :trace

    def initialize(trace)
      @trace = trace
    end

    # Main public method to format the trace as plain text
    def format
      parts = []
      parts << format_trace_header
      parts << format_trace_details
      parts << format_trace_annotations if trace.annotations.any?
      parts << ""
      parts << format_observations_section
      parts << SEPARATOR
      parts.join("\n")
    end

    private

    def format_trace_header
      [
        SEPARATOR,
        "TRACE: #{trace.name || 'Unnamed Trace'}",
        SEPARATOR
      ].join("\n")
    end

    def format_trace_details
      details = []
      details << "Trace ID: #{trace.trace_id}"
      details << "Start Time: #{format_time(trace.start_time)}"
      details << "End Time: #{format_time(trace.end_time)}" if trace.end_time
      details << "Duration: #{format_duration(trace.duration_ms)}" if trace.duration_ms
      details << "Total Cost: #{format_cost(trace.total_cost)}" if trace.total_cost && trace.total_cost > 0
      details << "Total Tokens: #{trace.total_tokens}" if trace.total_tokens && trace.total_tokens > 0

      if trace.user_id.present?
        details << "User ID: #{trace.user_id}"
      end

      if trace.release.present?
        details << "Release: #{trace.release}"
      end

      if trace.version.present?
        details << "Version: #{trace.version}"
      end

      if trace.input.present?
        details << ""
        details << "Input:"
        details << format_content(trace.input)
      end

      if trace.output.present?
        details << ""
        details << "Output:"
        details << format_content(trace.output)
      end

      if trace.metadata.present? && trace.metadata.any?
        details << ""
        details << "Metadata:"
        details << format_json(trace.metadata)
      end

      if trace.tags.present? && trace.tags.any?
        details << ""
        details << "Tags: #{trace.tags.to_json}"
      end

      details.join("\n")
    end

    def format_trace_annotations
      annotations = trace.annotations.order(created_at: :asc)
      return "" if annotations.empty?

      parts = []
      parts << ""
      parts << "--- ANNOTATIONS (#{annotations.count}) ---"

      annotations.each do |annotation|
        parts << format_annotation(annotation)
      end

      parts.join("\n")
    end

    def format_observations_section
      observations = trace.observations.order(start_time: :asc)
      return "No observations recorded." if observations.empty?

      parts = []
      parts << SEPARATOR
      parts << "OBSERVATIONS (#{observations.count})"
      parts << SEPARATOR
      parts << ""

      # Build tree structure
      observations_by_parent = observations.group_by(&:parent_observation_id)
      root_observations = observations_by_parent[nil] || []

      root_observations.each do |observation|
        parts << format_observation(observation, observations_by_parent, 0)
        parts << ""
      end

      parts.join("\n")
    end

    def format_observation(observation, observations_by_parent, depth)
      indent = INDENT * depth
      parts = []

      # Observation header
      parts << "#{indent}┌─ [#{observation.type.demodulize.upcase}] #{observation.name}"
      parts << "#{indent}│  Observation ID: #{observation.observation_id}"
      parts << "#{indent}│  Start: #{format_time(observation.start_time)}"
      parts << "#{indent}│  End: #{format_time(observation.end_time)}" if observation.end_time
      parts << "#{indent}│  Duration: #{format_duration(observation.duration_ms)}" if observation.duration_ms

      # Type-specific formatting
      if observation.is_a?(Observ::Generation)
        parts << format_generation_details(observation, indent)
      elsif observation.is_a?(Observ::Span)
        parts << format_span_details(observation, indent)
      end

      parts << "#{indent}└─ End of #{observation.type.demodulize.upcase}"

      # Recursively format child observations
      children = observations_by_parent[observation.observation_id] || []
      if children.any?
        parts << ""
        parts << "#{indent}  ┌─ CHILD OBSERVATIONS (#{children.count})"
        children.each do |child|
          parts << format_observation(child, observations_by_parent, depth + 1)
        end
        parts << "#{indent}  └─ END CHILD OBSERVATIONS"
      end

      parts.join("\n")
    end

    def format_generation_details(generation, indent)
      details = []

      if generation.model.present?
        details << "#{indent}│  Model: #{generation.model}"
      end

      if generation.cost_usd && generation.cost_usd > 0
        details << "#{indent}│  Cost: #{format_cost(generation.cost_usd)}"
      end

      if generation.usage.present? && generation.usage.any?
        details << "#{indent}│  "
        details << "#{indent}│  Usage:"
        generation.usage.each do |key, value|
          details << "#{indent}│    - #{key.to_s.humanize}: #{value}"
        end
      end

      if generation.model_parameters.present? && generation.model_parameters.any?
        details << "#{indent}│  "
        details << "#{indent}│  Model Parameters:"
        generation.model_parameters.each do |key, value|
          details << "#{indent}│    - #{key}: #{value}"
        end
      end

      if generation.prompt_name.present?
        details << "#{indent}│  Prompt Name: #{generation.prompt_name}"
        details << "#{indent}│  Prompt Version: #{generation.prompt_version}" if generation.prompt_version.present?
      end

      if generation.finish_reason.present?
        details << "#{indent}│  Finish Reason: #{generation.finish_reason}"
      end

      if generation.status_message.present?
        details << "#{indent}│  Status: #{generation.status_message}"
      end

      if generation.messages.present? && generation.messages.any?
        details << "#{indent}│  "
        details << "#{indent}│  Messages:"
        generation.messages.each_with_index do |msg, idx|
          details << "#{indent}│    [#{idx + 1}] #{msg['role']}: #{truncate_content(msg['content'], 200)}"
        end
      end

      if generation.tools.present? && generation.tools.any?
        details << "#{indent}│  "
        details << "#{indent}│  Tools Available: #{generation.tools.count}"
        generation.tools.first(3).each do |tool|
          tool_name = tool.is_a?(Hash) ? tool["name"] || tool[:name] : tool.to_s
          details << "#{indent}│    - #{tool_name}"
        end
        details << "#{indent}│    ... and #{generation.tools.count - 3} more" if generation.tools.count > 3
      end

      if generation.input.present?
        details << "#{indent}│  "
        details << "#{indent}│  Input:"
        format_content(generation.input).split("\n").each do |line|
          details << "#{indent}│  #{line}"
        end
      end

      if generation.output.present?
        details << "#{indent}│  "
        details << "#{indent}│  Output:"
        format_content(generation.output).split("\n").each do |line|
          details << "#{indent}│  #{line}"
        end
      end

      if generation.metadata.present? && generation.metadata.any?
        details << "#{indent}│  "
        details << "#{indent}│  Metadata:"
        format_json(generation.metadata).split("\n").each do |line|
          details << "#{indent}│  #{line}"
        end
      end

      if generation.provider_metadata.present? && generation.provider_metadata.any?
        details << "#{indent}│  "
        details << "#{indent}│  Provider Metadata:"
        format_json(generation.provider_metadata).split("\n").each do |line|
          details << "#{indent}│  #{line}"
        end
      end

      details.join("\n")
    end

    def format_span_details(span, indent)
      details = []

      if span.status_message.present?
        details << "#{indent}│  Status: #{span.status_message}"
      end

      if span.input.present?
        details << "#{indent}│  "
        details << "#{indent}│  Input:"
        format_content(span.input).split("\n").each do |line|
          details << "#{indent}│  #{line}"
        end
      end

      if span.output.present?
        details << "#{indent}│  "
        details << "#{indent}│  Output:"
        format_content(span.output).split("\n").each do |line|
          details << "#{indent}│  #{line}"
        end
      end

      if span.metadata.present? && span.metadata.any?
        details << "#{indent}│  "
        details << "#{indent}│  Metadata:"
        format_json(span.metadata).split("\n").each do |line|
          details << "#{indent}│  #{line}"
        end
      end

      details.join("\n")
    end

    def format_annotation(annotation, prefix = "")
      parts = []
      timestamp = format_time(annotation.created_at)

      if annotation.annotator.present?
        parts << "#{prefix}[#{timestamp}] #{annotation.annotator}"
      else
        parts << "#{prefix}[#{timestamp}]"
      end

      parts << "#{prefix}#{annotation.content}"

      if annotation.tags.present? && annotation.tags.any?
        parts << "#{prefix}Tags: #{annotation.tags.to_json}"
      end

      parts << ""
      parts.join("\n")
    end

    def format_time(time)
      return "N/A" unless time
      time.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
    end

    def format_duration(duration_ms)
      return "N/A" unless duration_ms
      "#{duration_ms}ms"
    end

    def format_cost(cost)
      return "$0.000000" unless cost
      "$#{sprintf('%.6f', cost)}"
    end

    def format_content(content)
      return "" if content.blank?

      # Try to parse as JSON for pretty printing
      if content.is_a?(String)
        begin
          parsed = JSON.parse(content)
          return format_json(parsed)
        rescue JSON::ParserError
          # Not JSON, return as-is
        end
      end

      truncate_content(content.to_s)
    end

    def format_json(obj)
      JSON.pretty_generate(obj)
    rescue StandardError
      obj.to_s
    end

    def truncate_content(content, max_length = MAX_CONTENT_LENGTH)
      return "" if content.blank?

      content_str = content.to_s
      return content_str if content_str.length <= max_length

      "#{content_str[0...max_length]}...\n[Content truncated, original length: #{content_str.length} characters]"
    end
  end
end
