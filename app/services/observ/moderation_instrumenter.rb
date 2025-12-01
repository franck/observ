# frozen_string_literal: true

module Observ
  class ModerationInstrumenter
    attr_reader :session, :context

    def initialize(session, context: {})
      @session = session
      @context = context
      @original_moderate_method = nil
      @instrumented = false
    end

    def instrument!
      return if @instrumented

      wrap_moderate_method
      @instrumented = true

      Rails.logger.info "[Observability] Instrumented RubyLLM.moderate for session #{session.session_id}"
    end

    def uninstrument!
      return unless @instrumented
      return unless @original_moderate_method

      RubyLLM.define_singleton_method(:moderate, @original_moderate_method)
      @instrumented = false

      Rails.logger.info "[Observability] Uninstrumented RubyLLM.moderate"
    end

    private

    def wrap_moderate_method
      return if @original_moderate_method

      @original_moderate_method = RubyLLM.method(:moderate)
      instrumenter = self

      RubyLLM.define_singleton_method(:moderate) do |*args, **kwargs|
        instrumenter.send(:handle_moderate_call, args, kwargs)
      end
    end

    def handle_moderate_call(args, kwargs)
      text = args[0]
      model_id = kwargs[:model] || default_moderation_model

      trace = session.create_trace(
        name: "moderation",
        input: { text: text&.truncate(500) },
        metadata: @context.merge(
          model: model_id
        ).compact
      )

      moderation_obs = trace.create_moderation(
        name: "moderate",
        model: model_id,
        metadata: {}
      )

      result = @original_moderate_method.call(*args, **kwargs)

      finalize_moderation(moderation_obs, result, text)
      trace.finalize(
        output: format_output(result),
        metadata: extract_trace_metadata(result)
      )

      result
    rescue StandardError => e
      handle_error(e, trace, moderation_obs)
      raise
    end

    def finalize_moderation(moderation_obs, result, text)
      moderation_obs.finalize(
        output: format_output(result),
        usage: {},
        cost_usd: 0.0 # Moderation is typically free
      )

      moderation_obs.update!(
        input: text&.truncate(1000),
        metadata: moderation_obs.metadata.merge(
          flagged: result.flagged?,
          categories: result.categories,
          category_scores: result.category_scores,
          flagged_categories: result.flagged_categories
        ).compact
      )
    end

    def format_output(result)
      {
        model: result.model,
        flagged: result.flagged?,
        flagged_categories: result.flagged_categories,
        id: result.respond_to?(:id) ? result.id : nil
      }.compact
    end

    def extract_trace_metadata(result)
      {
        flagged: result.flagged?,
        flagged_categories_count: result.flagged_categories&.count || 0
      }.compact
    end

    def default_moderation_model
      if RubyLLM.config.respond_to?(:default_moderation_model)
        RubyLLM.config.default_moderation_model
      else
        "omni-moderation-latest"
      end
    end

    def handle_error(error, trace, moderation_obs)
      return unless trace

      error_span = trace.create_span(
        name: "error",
        metadata: {
          error_type: error.class.name,
          level: "ERROR"
        },
        input: {
          error_message: error.message,
          backtrace: error.backtrace&.first(10)
        }.to_json
      )
      error_span.finalize(output: { error_captured: true }.to_json)

      moderation_obs&.update(status_message: "FAILED") rescue nil

      Rails.logger.error "[Observability] Moderation error captured: #{error.class.name} - #{error.message}"
    end
  end
end
