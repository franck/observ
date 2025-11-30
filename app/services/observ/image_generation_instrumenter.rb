# frozen_string_literal: true

module Observ
  class ImageGenerationInstrumenter
    attr_reader :session, :context

    def initialize(session, context: {})
      @session = session
      @context = context
      @original_paint_method = nil
      @instrumented = false
    end

    def instrument!
      return if @instrumented

      wrap_paint_method
      @instrumented = true

      Rails.logger.info "[Observability] Instrumented RubyLLM.paint for session #{session.session_id}"
    end

    def uninstrument!
      return unless @instrumented
      return unless @original_paint_method

      RubyLLM.define_singleton_method(:paint, @original_paint_method)
      @instrumented = false

      Rails.logger.info "[Observability] Uninstrumented RubyLLM.paint"
    end

    private

    def wrap_paint_method
      return if @original_paint_method

      @original_paint_method = RubyLLM.method(:paint)
      instrumenter = self

      RubyLLM.define_singleton_method(:paint) do |*args, **kwargs|
        instrumenter.send(:handle_paint_call, args, kwargs)
      end
    end

    def handle_paint_call(args, kwargs)
      prompt = args[0]
      model_id = kwargs[:model] || default_image_model
      size = kwargs[:size]

      trace = session.create_trace(
        name: "image_generation",
        input: { prompt: prompt },
        metadata: @context.merge(
          model: model_id,
          size: size
        ).compact
      )

      image_obs = trace.create_image_generation(
        name: "paint",
        model: model_id,
        metadata: {
          size: size
        }.compact
      )

      result = @original_paint_method.call(*args, **kwargs)

      finalize_image_generation(image_obs, result, prompt)
      trace.finalize(
        output: format_output(result),
        metadata: { size: extract_size(result) }
      )

      result
    rescue StandardError => e
      handle_error(e, trace, image_obs)
      raise
    end

    def finalize_image_generation(image_obs, result, prompt)
      cost = calculate_cost(result)

      image_obs.finalize(
        output: format_output(result),
        usage: {},
        cost_usd: cost
      )

      image_obs.update!(
        input: prompt,
        metadata: image_obs.metadata.merge(
          revised_prompt: result.revised_prompt,
          output_format: result.base64? ? "base64" : "url",
          mime_type: result.mime_type,
          size: extract_size(result)
        ).compact
      )
    end

    def calculate_cost(result)
      model_id = result.model_id
      return 0.0 unless model_id

      model_info = RubyLLM.models.find(model_id)
      return 0.0 unless model_info

      # Image models typically have per-image pricing
      # Check for image_price or fall back to output_price_per_million
      if model_info.respond_to?(:image_price) && model_info.image_price
        model_info.image_price
      elsif model_info.respond_to?(:output_price_per_million) && model_info.output_price_per_million
        # Some providers might use output pricing
        model_info.output_price_per_million / 1000.0
      else
        0.0
      end
    rescue StandardError => e
      Rails.logger.warn "[Observability] Failed to calculate image generation cost: #{e.message}"
      0.0
    end

    def extract_size(result)
      # Try to get size from result if available
      result.respond_to?(:size) ? result.size : nil
    end

    def format_output(result)
      {
        model: result.model_id,
        has_url: result.respond_to?(:url) && result.url.present?,
        base64: result.base64?,
        mime_type: result.mime_type,
        revised_prompt: result.revised_prompt
      }.compact
    end

    def default_image_model
      if RubyLLM.config.respond_to?(:default_image_model)
        RubyLLM.config.default_image_model
      else
        "dall-e-3"
      end
    end

    def handle_error(error, trace, image_obs)
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

      image_obs&.update(status_message: "FAILED") rescue nil

      Rails.logger.error "[Observability] Image generation error captured: #{error.class.name} - #{error.message}"
    end
  end
end
