# frozen_string_literal: true

module Observ
  class ImageGeneration < Observation
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

    # Image-specific helpers
    def size
      metadata&.dig("size")
    end

    def quality
      metadata&.dig("quality")
    end

    def revised_prompt
      metadata&.dig("revised_prompt")
    end

    def output_format
      metadata&.dig("output_format") # "url" or "base64"
    end

    def mime_type
      metadata&.dig("mime_type")
    end
  end
end
