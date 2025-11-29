# frozen_string_literal: true

module Observ
  class EmbeddingInstrumenter
    attr_reader :session, :context

    def initialize(session, context: {})
      @session = session
      @context = context
      @original_embed_method = nil
      @instrumented = false
    end

    def instrument!
      return if @instrumented

      wrap_embed_method
      @instrumented = true

      Rails.logger.info "[Observability] Instrumented RubyLLM.embed for session #{session.session_id}"
    end

    def uninstrument!
      return unless @instrumented
      return unless @original_embed_method

      RubyLLM.define_singleton_method(:embed, @original_embed_method)
      @instrumented = false

      Rails.logger.info "[Observability] Uninstrumented RubyLLM.embed"
    end

    private

    def wrap_embed_method
      return if @original_embed_method

      @original_embed_method = RubyLLM.method(:embed)
      instrumenter = self

      RubyLLM.define_singleton_method(:embed) do |*args, **kwargs|
        instrumenter.send(:handle_embed_call, args, kwargs)
      end
    end

    def handle_embed_call(args, kwargs)
      texts = args[0]
      model_id = kwargs[:model] || default_embedding_model

      trace = session.create_trace(
        name: "embedding",
        input: format_input(texts),
        metadata: @context.merge(
          batch_size: Array(texts).size,
          model: model_id
        )
      )

      embedding_obs = trace.create_embedding(
        name: "embed",
        model: model_id,
        metadata: {
          batch_size: Array(texts).size
        }
      )
      embedding_obs.set_input(texts)

      call_start_time = Time.current
      result = @original_embed_method.call(*args, **kwargs)

      finalize_embedding(embedding_obs, result, call_start_time)
      trace.finalize(
        output: format_output(result),
        metadata: { dimensions: extract_dimensions(result) }
      )

      result
    rescue StandardError => e
      handle_error(e, trace, embedding_obs)
      raise
    end

    def finalize_embedding(embedding_obs, result, _call_start_time)
      usage = extract_usage(result)
      cost = calculate_cost(result)
      dimensions = extract_dimensions(result)
      vectors_count = extract_vectors_count(result)

      embedding_obs.finalize(
        output: format_output(result),
        usage: usage,
        cost_usd: cost
      )

      embedding_obs.update!(
        metadata: embedding_obs.metadata.merge(
          dimensions: dimensions,
          vectors_count: vectors_count
        )
      )
    end

    def extract_usage(result)
      {
        input_tokens: result.input_tokens || 0,
        total_tokens: result.input_tokens || 0
      }
    end

    def calculate_cost(result)
      model_id = result.model
      return 0.0 unless model_id

      model_info = RubyLLM.models.find(model_id)
      return 0.0 unless model_info&.input_price_per_million

      input_tokens = result.input_tokens || 0
      (input_tokens * model_info.input_price_per_million / 1_000_000.0).round(6)
    rescue StandardError => e
      Rails.logger.warn "[Observability] Failed to calculate embedding cost: #{e.message}"
      0.0
    end

    def extract_dimensions(result)
      vectors = result.vectors
      return nil unless vectors

      # Handle both single embedding and batch embeddings
      if vectors.first.is_a?(Array)
        vectors.first.length
      else
        vectors.length
      end
    end

    def extract_vectors_count(result)
      vectors = result.vectors
      return 1 unless vectors

      # Handle both single embedding and batch embeddings
      if vectors.first.is_a?(Array)
        vectors.length
      else
        1
      end
    end

    def format_input(texts)
      if texts.is_a?(Array)
        { texts: texts, count: texts.size }
      else
        { text: texts }
      end
    end

    def format_output(result)
      {
        model: result.model,
        dimensions: extract_dimensions(result),
        vectors_count: extract_vectors_count(result)
      }
    end

    def default_embedding_model
      if RubyLLM.config.respond_to?(:default_embedding_model)
        RubyLLM.config.default_embedding_model
      else
        "text-embedding-3-small"
      end
    end

    def handle_error(error, trace, embedding_obs)
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

      embedding_obs&.update(status_message: "FAILED") rescue nil

      Rails.logger.error "[Observability] Embedding error captured: #{error.class.name} - #{error.message}"
    end
  end
end
