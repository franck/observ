# frozen_string_literal: true

module Observ
  class ModerationGuardrailJob < ApplicationJob
    queue_as :moderation

    # Retry configuration
    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    # Process a single trace or session
    #
    # @param trace_id [Integer] ID of the trace to moderate
    # @param session_id [Integer] ID of the session to moderate
    # @param options [Hash] Options for moderation
    # @option options [Boolean] :moderate_input Whether to moderate input (default: true)
    # @option options [Boolean] :moderate_output Whether to moderate output (default: true)
    # @option options [Boolean] :aggregate Whether to moderate aggregated session content
    def perform(trace_id: nil, session_id: nil, **options)
      if trace_id
        moderate_trace(trace_id, options)
      elsif session_id
        moderate_session(session_id, options)
      else
        Rails.logger.warn "[ModerationGuardrailJob] No trace_id or session_id provided"
      end
    end

    # Class method to enqueue moderation for traces matching criteria
    #
    # @param scope [ActiveRecord::Relation] Scope of traces to moderate
    # @param sample_percentage [Integer] Percentage of traces to sample (1-100)
    def self.enqueue_for_scope(scope, sample_percentage: 100)
      traces = scope.left_joins(:review_item)
                    .where(observ_review_items: { id: nil })

      if sample_percentage < 100
        sample_size = (traces.count * sample_percentage / 100.0).ceil
        traces = traces.order("RANDOM()").limit(sample_size)
      end

      traces.find_each do |trace|
        perform_later(trace_id: trace.id)
      end
    end

    # Enqueue moderation for user-facing sessions only
    #
    # @param since [Time] Only process sessions created after this time
    def self.enqueue_user_facing(since: 1.hour.ago)
      Observ::Session
        .where(created_at: since..)
        .where("metadata->>'user_facing' = ?", "true")
        .find_each do |session|
          perform_later(session_id: session.id)
        end
    end

    # Enqueue moderation for specific agent types
    #
    # @param agent_types [Array<String>] Agent types to moderate
    # @param since [Time] Only process sessions created after this time
    def self.enqueue_for_agent_types(agent_types, since: 1.hour.ago)
      Observ::Session
        .where(created_at: since..)
        .where("metadata->>'agent_type' IN (?)", agent_types)
        .find_each do |session|
          perform_later(session_id: session.id)
        end
    end

    private

    def moderate_trace(trace_id, options)
      trace = Observ::Trace.find(trace_id)

      service = ModerationGuardrailService.new
      result = service.evaluate_trace(
        trace,
        moderate_input: options.fetch(:moderate_input, true),
        moderate_output: options.fetch(:moderate_output, true)
      )

      log_result("Trace #{trace_id}", result)
    end

    def moderate_session(session_id, options)
      session = Observ::Session.find(session_id)

      service = ModerationGuardrailService.new

      if options[:aggregate]
        # Moderate aggregated session content
        result = service.evaluate_session_content(session)
        log_result("Session #{session_id} (aggregated)", result)
      else
        # Moderate each trace individually
        results = service.evaluate_session(session)
        flagged_count = results.count(&:flagged?)
        Rails.logger.info "[ModerationGuardrailJob] Session #{session_id}: #{flagged_count}/#{results.size} traces flagged"
      end
    end

    def log_result(identifier, result)
      case result.action
      when :flagged
        Rails.logger.info "[ModerationGuardrailJob] #{identifier} flagged (#{result.priority}): #{result.details[:flagged_categories]}"
      when :skipped
        Rails.logger.debug "[ModerationGuardrailJob] #{identifier} skipped: #{result.reason}"
      when :passed
        Rails.logger.debug "[ModerationGuardrailJob] #{identifier} passed moderation"
      end
    end
  end
end
