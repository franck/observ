# frozen_string_literal: true

module Observ
  class ModerationGuardrailService
    include Observ::Concerns::ObservableService

    # Score thresholds for different actions
    THRESHOLDS = {
      critical: 0.9,  # Auto-flag as critical
      high: 0.7,      # Flag as high priority
      review: 0.5     # Flag for normal review
    }.freeze

    # Categories that always trigger critical review
    CRITICAL_CATEGORIES = %w[
      sexual/minors
      self-harm/intent
      self-harm/instructions
      violence/graphic
    ].freeze

    class Result
      attr_reader :action, :reason, :priority, :details

      def initialize(action:, reason: nil, priority: nil, details: {})
        @action = action
        @reason = reason
        @priority = priority
        @details = details
      end

      def flagged? = action == :flagged
      def skipped? = action == :skipped
      def passed? = action == :passed
    end

    def initialize(observability_session: nil)
      initialize_observability(
        observability_session,
        service_name: "moderation_guardrail",
        metadata: {}
      )
    end

    # Evaluate a trace for moderation issues
    #
    # @param trace [Observ::Trace] The trace to evaluate
    # @param moderate_input [Boolean] Whether to moderate input content
    # @param moderate_output [Boolean] Whether to moderate output content
    # @return [Result] The evaluation result
    def evaluate_trace(trace, moderate_input: true, moderate_output: true)
      return Result.new(action: :skipped, reason: "already_in_queue") if trace.in_review_queue?
      return Result.new(action: :skipped, reason: "already_has_moderation") if has_existing_flags?(trace)

      with_observability do |_session|
        content = extract_trace_content(
          trace,
          moderate_input: moderate_input,
          moderate_output: moderate_output
        )
        return Result.new(action: :skipped, reason: "no_content") if content.blank?

        perform_moderation(trace, content)
      end
    rescue StandardError => e
      Rails.logger.error "[ModerationGuardrailService] Failed to evaluate trace #{trace.id}: #{e.message}"
      Result.new(action: :skipped, reason: "error", details: { error: e.message })
    end

    # Evaluate all traces in a session
    #
    # @param session [Observ::Session] The session to evaluate
    # @return [Array<Result>] Results for each trace
    def evaluate_session(session)
      return [] if session.traces.empty?

      session.traces.map do |trace|
        evaluate_trace(trace)
      end
    end

    # Evaluate session-level content (aggregated input/output)
    #
    # @param session [Observ::Session] The session to evaluate
    # @return [Result] The evaluation result
    def evaluate_session_content(session)
      return Result.new(action: :skipped, reason: "already_in_queue") if session.in_review_queue?

      with_observability do |_session|
        content = extract_session_content(session)
        return Result.new(action: :skipped, reason: "no_content") if content.blank?

        perform_session_moderation(session, content)
      end
    rescue StandardError => e
      Rails.logger.error "[ModerationGuardrailService] Failed to evaluate session #{session.id}: #{e.message}"
      Result.new(action: :skipped, reason: "error", details: { error: e.message })
    end

    private

    def has_existing_flags?(trace)
      trace.moderations.any?(&:flagged?)
    end

    def extract_trace_content(trace, moderate_input:, moderate_output:)
      parts = []
      parts << extract_text(trace.input) if moderate_input
      parts << extract_text(trace.output) if moderate_output
      parts.compact.reject(&:blank?).join("\n\n---\n\n")
    end

    def extract_session_content(session)
      session.traces.flat_map do |trace|
        [extract_text(trace.input), extract_text(trace.output)]
      end.compact.reject(&:blank?).join("\n\n---\n\n").truncate(10_000)
    end

    def extract_text(content)
      return nil if content.blank?

      case content
      when String
        content
      when Hash
        # Try common keys for text content
        content["text"] || content["content"] || content["message"] ||
          content[:text] || content[:content] || content[:message] ||
          content.to_json
      else
        content.to_s
      end
    end

    def perform_moderation(trace, content)
      instrument_moderation(context: {
        service: "moderation_guardrail",
        trace_id: trace.id,
        content_length: content.length
      })

      result = RubyLLM.moderate(content)

      evaluate_and_enqueue(trace, result)
    end

    def perform_session_moderation(session, content)
      instrument_moderation(context: {
        service: "moderation_guardrail",
        session_id: session.id,
        content_length: content.length
      })

      result = RubyLLM.moderate(content)

      evaluate_and_enqueue_session(session, result)
    end

    def evaluate_and_enqueue(trace, moderation_result)
      priority = determine_priority(moderation_result)

      if priority
        details = build_details(moderation_result)
        trace.enqueue_for_review!(
          reason: "content_moderation",
          priority: priority,
          details: details
        )

        Result.new(
          action: :flagged,
          priority: priority,
          details: details
        )
      else
        Result.new(action: :passed)
      end
    end

    def evaluate_and_enqueue_session(session, moderation_result)
      priority = determine_priority(moderation_result)

      if priority
        details = build_details(moderation_result)
        session.enqueue_for_review!(
          reason: "content_moderation",
          priority: priority,
          details: details
        )

        Result.new(
          action: :flagged,
          priority: priority,
          details: details
        )
      else
        Result.new(action: :passed)
      end
    end

    def determine_priority(result)
      # Check for critical categories first
      if (result.flagged_categories & CRITICAL_CATEGORIES).any?
        return :critical
      end

      # Check if explicitly flagged
      if result.flagged?
        max_score = result.category_scores.values.max || 0
        return max_score >= THRESHOLDS[:critical] ? :critical : :high
      end

      # Check score thresholds even if not flagged
      max_score = result.category_scores.values.max || 0

      if max_score >= THRESHOLDS[:high]
        :high
      elsif max_score >= THRESHOLDS[:review]
        :normal
      end
    end

    def build_details(result)
      {
        flagged: result.flagged?,
        flagged_categories: result.flagged_categories,
        highest_category: highest_category(result),
        highest_score: result.category_scores.values.max&.round(4),
        category_scores: result.category_scores.transform_values { |v| v.round(4) }
      }
    end

    def highest_category(result)
      return nil if result.category_scores.empty?

      result.category_scores.max_by { |_, score| score }&.first
    end
  end
end
