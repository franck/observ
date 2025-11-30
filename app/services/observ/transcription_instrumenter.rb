# frozen_string_literal: true

module Observ
  class TranscriptionInstrumenter
    attr_reader :session, :context

    def initialize(session, context: {})
      @session = session
      @context = context
      @original_transcribe_method = nil
      @instrumented = false
    end

    def instrument!
      return if @instrumented

      wrap_transcribe_method
      @instrumented = true

      Rails.logger.info "[Observability] Instrumented RubyLLM.transcribe for session #{session.session_id}"
    end

    def uninstrument!
      return unless @instrumented
      return unless @original_transcribe_method

      RubyLLM.define_singleton_method(:transcribe, @original_transcribe_method)
      @instrumented = false

      Rails.logger.info "[Observability] Uninstrumented RubyLLM.transcribe"
    end

    private

    def wrap_transcribe_method
      return if @original_transcribe_method

      @original_transcribe_method = RubyLLM.method(:transcribe)
      instrumenter = self

      RubyLLM.define_singleton_method(:transcribe) do |*args, **kwargs|
        instrumenter.send(:handle_transcribe_call, args, kwargs)
      end
    end

    def handle_transcribe_call(args, kwargs)
      audio_path = args[0]
      model_id = kwargs[:model] || default_transcription_model
      language = kwargs[:language]

      trace = session.create_trace(
        name: "transcription",
        input: { audio_path: audio_path.to_s },
        metadata: @context.merge(
          model: model_id,
          language: language
        ).compact
      )

      transcription_obs = trace.create_transcription(
        name: "transcribe",
        model: model_id,
        metadata: {
          language: language,
          has_diarization: kwargs[:speaker_names].present?
        }.compact
      )

      result = @original_transcribe_method.call(*args, **kwargs)

      finalize_transcription(transcription_obs, result)
      trace.finalize(
        output: format_output(result),
        metadata: extract_trace_metadata(result)
      )

      result
    rescue StandardError => e
      handle_error(e, trace, transcription_obs)
      raise
    end

    def finalize_transcription(transcription_obs, result)
      cost = calculate_cost(result)

      transcription_obs.finalize(
        output: format_output(result),
        usage: {},
        cost_usd: cost
      )

      transcription_obs.update!(
        input: result.text&.truncate(1000),
        metadata: transcription_obs.metadata.merge(
          audio_duration_s: result.duration,
          language: result.respond_to?(:language) ? result.language : nil,
          segments_count: result.segments&.count || 0,
          speakers_count: extract_speakers_count(result),
          has_diarization: has_diarization?(result)
        ).compact
      )
    end

    def calculate_cost(result)
      model_id = result.model
      return 0.0 unless model_id

      model_info = RubyLLM.models.find(model_id)
      return 0.0 unless model_info

      duration_minutes = (result.duration || 0) / 60.0

      # Transcription models typically use per-minute pricing
      if model_info.respond_to?(:audio_price_per_minute) && model_info.audio_price_per_minute
        (duration_minutes * model_info.audio_price_per_minute).round(6)
      elsif model_info.respond_to?(:input_price_per_million) && model_info.input_price_per_million
        # Fallback: some models might use token-based pricing
        # Estimate ~150 tokens per minute of audio
        estimated_tokens = duration_minutes * 150
        (estimated_tokens * model_info.input_price_per_million / 1_000_000.0).round(6)
      else
        0.0
      end
    rescue StandardError => e
      Rails.logger.warn "[Observability] Failed to calculate transcription cost: #{e.message}"
      0.0
    end

    def extract_speakers_count(result)
      return nil unless has_diarization?(result)
      return nil unless result.segments

      result.segments.map { |s| s.respond_to?(:speaker) ? s.speaker : nil }.compact.uniq.count
    end

    def has_diarization?(result)
      return false unless result.segments&.any?

      result.segments.first.respond_to?(:speaker)
    end

    def format_output(result)
      {
        model: result.model,
        text_length: result.text&.length || 0,
        duration_s: result.duration,
        segments_count: result.segments&.count || 0
      }.compact
    end

    def extract_trace_metadata(result)
      {
        audio_duration_s: result.duration,
        language: result.respond_to?(:language) ? result.language : nil
      }.compact
    end

    def default_transcription_model
      if RubyLLM.config.respond_to?(:default_transcription_model)
        RubyLLM.config.default_transcription_model
      else
        "whisper-1"
      end
    end

    def handle_error(error, trace, transcription_obs)
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

      transcription_obs&.update(status_message: "FAILED") rescue nil

      Rails.logger.error "[Observability] Transcription error captured: #{error.class.name} - #{error.message}"
    end
  end
end
