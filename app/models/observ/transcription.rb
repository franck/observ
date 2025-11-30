# frozen_string_literal: true

module Observ
  class Transcription < Observation
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

    # Transcription-specific helpers
    def audio_duration_s
      metadata&.dig("audio_duration_s")
    end

    def language
      metadata&.dig("language")
    end

    def segments_count
      metadata&.dig("segments_count") || 0
    end

    def speakers_count
      metadata&.dig("speakers_count")
    end

    def has_diarization?
      metadata&.dig("has_diarization") || false
    end
  end
end
