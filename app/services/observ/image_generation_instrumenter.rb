# frozen_string_literal: true

module Observ
  class ImageGenerationInstrumenter
    # Hardcoded pricing for image generation models (USD per image)
    # Prices are organized by model_id, then by size, then by quality
    # Source: https://openai.com/pricing, https://cloud.google.com/vertex-ai/pricing
    IMAGE_PRICING = {
      # OpenAI DALL-E 3 (size and quality based)
      # Quality options: "standard", "hd"
      "dall-e-3" => {
        "1024x1024" => { "standard" => 0.04, "hd" => 0.08 },
        "1792x1024" => { "standard" => 0.08, "hd" => 0.12 },
        "1024x1792" => { "standard" => 0.08, "hd" => 0.12 }
      },
      # OpenAI DALL-E 2 (size based, no quality option)
      "dall-e-2" => {
        "1024x1024" => { "default" => 0.02 },
        "512x512" => { "default" => 0.018 },
        "256x256" => { "default" => 0.016 }
      },
      # OpenAI GPT-image-1 (token-based, estimated per-image costs)
      # Quality options: "low", "medium", "high" (maps "standard" -> "medium")
      # Source: "Image outputs cost approximately $0.01 (low), $0.04 (medium), $0.17 (high) for square images"
      # Larger sizes are estimated at ~1.7x for 1792x1024 and ~2.9x for 1792x1792
      "gpt-image-1" => {
        "1024x1024" => { "low" => 0.01, "medium" => 0.04, "high" => 0.17 },
        "1792x1024" => { "low" => 0.017, "medium" => 0.068, "high" => 0.29 },
        "1024x1792" => { "low" => 0.017, "medium" => 0.068, "high" => 0.29 },
        "1792x1792" => { "low" => 0.029, "medium" => 0.116, "high" => 0.49 },
        "default" => { "low" => 0.01, "medium" => 0.04, "high" => 0.17 }
      },
      # OpenAI GPT-image-1-mini (token-based, estimated per-image costs)
      # Approximately 5x cheaper than gpt-image-1 based on token pricing ratio
      "gpt-image-1-mini" => {
        "1024x1024" => { "low" => 0.002, "medium" => 0.008, "high" => 0.034 },
        "1792x1024" => { "low" => 0.0034, "medium" => 0.0136, "high" => 0.058 },
        "1024x1792" => { "low" => 0.0034, "medium" => 0.0136, "high" => 0.058 },
        "1792x1792" => { "low" => 0.0058, "medium" => 0.0232, "high" => 0.098 },
        "default" => { "low" => 0.002, "medium" => 0.008, "high" => 0.034 }
      },
      # Google Imagen models (flat rate per image)
      "imagen-3.0-generate-002" => {
        "default" => { "default" => 0.04 }
      },
      "imagen-4.0-generate-001" => {
        "default" => { "default" => 0.04 }
      },
      "imagen-4.0-generate-preview-06-06" => {
        "default" => { "default" => 0.04 }
      },
      "imagen-4.0-ultra-generate-preview-06-06" => {
        "default" => { "default" => 0.08 }
      }
    }.freeze

    # Maps quality names between different conventions
    # DALL-E uses: "standard", "hd"
    # GPT-image uses: "low", "medium", "high"
    QUALITY_MAPPINGS = {
      "standard" => "medium",  # Map DALL-E "standard" to GPT-image "medium"
      "hd" => "high"           # Map DALL-E "hd" to GPT-image "high"
    }.freeze

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
      size = kwargs[:size] || "1024x1024"
      quality = kwargs[:quality] || "standard"

      trace = session.create_trace(
        name: "image_generation",
        input: { prompt: prompt },
        metadata: @context.merge(
          model: model_id,
          size: size,
          quality: quality
        ).compact
      )

      image_obs = trace.create_image_generation(
        name: "paint",
        model: model_id,
        metadata: {
          size: size,
          quality: quality
        }.compact
      )

      result = @original_paint_method.call(*args, **kwargs)

      finalize_image_generation(image_obs, result, prompt, size: size, quality: quality)
      trace.finalize(
        output: format_output(result),
        metadata: { size: extract_size(result) || size, quality: quality }
      )

      result
    rescue StandardError => e
      handle_error(e, trace, image_obs)
      raise
    end

    def finalize_image_generation(image_obs, result, prompt, size:, quality:)
      cost = calculate_cost(result, size: size, quality: quality)

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
          size: extract_size(result) || size,
          quality: quality
        ).compact
      )
    end

    def calculate_cost(result, size:, quality:)
      model_id = result.model_id
      return 0.0 unless model_id

      lookup_image_price(model_id, size, quality)
    rescue StandardError => e
      Rails.logger.warn "[Observability] Failed to calculate image generation cost: #{e.message}"
      0.0
    end

    def lookup_image_price(model_id, size, quality)
      model_pricing = IMAGE_PRICING[model_id]
      return 0.0 unless model_pricing

      # Try exact size match, then "default"
      size_pricing = model_pricing[size] || model_pricing["default"]
      return 0.0 unless size_pricing

      # Try exact quality match first
      return size_pricing[quality] if size_pricing[quality]

      # Try mapped quality (e.g., "standard" -> "medium" for GPT-image models)
      mapped_quality = QUALITY_MAPPINGS[quality]
      return size_pricing[mapped_quality] if mapped_quality && size_pricing[mapped_quality]

      # Fall back to "standard", "medium", "default", or first available
      size_pricing["standard"] ||
        size_pricing["medium"] ||
        size_pricing["default"] ||
        size_pricing.values.first ||
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
