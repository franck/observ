# frozen_string_literal: true

module Observ
  class Embedding < Observation
    # Set input texts for the embedding call
    def set_input(texts)
      update!(
        input: texts.is_a?(Array) ? texts.to_json : texts
      )
    end

    def finalize(output:, usage: {}, cost_usd: 0.0, status_message: nil)
      merged_usage = (self.usage || {}).merge(usage.stringify_keys)

      update!(
        output: output.is_a?(String) ? output : output.to_json,
        usage: merged_usage,
        cost_usd: cost_usd,
        end_time: Time.current,
        status_message: status_message
      )
    end

    # Embedding-specific helpers
    def input_tokens
      usage&.dig("input_tokens") || 0
    end

    def total_tokens
      input_tokens # Embeddings only have input tokens
    end

    def batch_size
      metadata&.dig("batch_size") || 1
    end

    def dimensions
      metadata&.dig("dimensions")
    end

    def vectors_count
      metadata&.dig("vectors_count") || 1
    end
  end
end
