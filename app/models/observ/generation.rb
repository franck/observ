# frozen_string_literal: true

module Observ
  class Generation < Observation
    def set_input(input, messages: nil)
      update!(
        input: input.is_a?(String) ? input : input.to_json,
        messages: messages || self.messages
      )
    end

    def set_messages(messages)
      update!(messages: messages)
    end

    def set_tools(tools, tool_choice: nil)
      update!(tools: tools, tool_choice: tool_choice)
    end

    def finalize(output:, usage: {}, cost_usd: 0.0, status_message: nil, finish_reason: nil,
                 completion_start_time: nil, provider_metadata: {}, messages: nil, raw_response: nil)
      merged_usage = (self.usage || {}).merge(usage.stringify_keys)
      merged_provider_metadata = (self.provider_metadata || {}).merge(provider_metadata.stringify_keys)

      update!(
        output: output.is_a?(String) ? output : output.to_json,
        usage: merged_usage,
        cost_usd: cost_usd,
        finish_reason: finish_reason,
        completion_start_time: completion_start_time,
        provider_metadata: merged_provider_metadata,
        messages: messages || self.messages,
        raw_response: raw_response,
        end_time: Time.current,
        status_message: status_message
      )
    end

    def time_to_first_token_ms
      return nil unless completion_start_time && start_time
      ((completion_start_time - start_time) * 1000).round(2)
    end

    def total_tokens
      usage&.dig("total_tokens") || 0
    end

    def input_tokens
      usage&.dig("input_tokens") || 0
    end

    def output_tokens
      usage&.dig("output_tokens") || 0
    end
  end
end
