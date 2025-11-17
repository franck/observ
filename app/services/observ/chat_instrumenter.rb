# frozen_string_literal: true

module Observ
  class ChatInstrumenter
    attr_reader :session, :chat, :current_trace, :current_tool_span

    def initialize(session, chat, context: {})
      @session = session
      @chat = chat
      @context = context
      @current_trace = nil
      @current_tool_span = nil
      @original_ask_method = nil
      @instrumented = false
    end

    def instrument!
      return if @instrumented

      wrap_ask_method
      setup_event_handlers
      @instrumented = true

      Rails.logger.info "[Observability] Instrumented chat for session #{session.session_id}"
    end

    def create_trace(name: "chat_exchange", input: nil, metadata: {})
      @current_trace = session.create_trace(
        name: name,
        input: input,
        metadata: @context.merge(metadata)
      )
    end

    def finalize_current_trace(output: nil)
      return unless @current_trace

      @current_trace.finalize(output: output)
      @current_trace = nil
    end

    private

    def wrap_ask_method
      return if @original_ask_method

      @original_ask_method = chat.method(:ask)
      instrumenter = self

      chat.define_singleton_method(:ask) do |*args, **kwargs, &block|
        instrumenter.send(:handle_ask_call, self, args, kwargs, block)
      end
    end

    def handle_ask_call(chat_instance, args, kwargs, block)
      user_message = args[0]
      attachments = kwargs[:with]

      # Track if this is an ephemeral trace (created just for this call)
      is_ephemeral_trace = @current_trace.nil?

      trace = @current_trace || create_trace(
        name: "chat.ask",
        input: format_input(user_message, attachments),
        metadata: {
          has_attachments: attachments.present?,
          attachment_count: Array(attachments).size
        }
      )

      model_id = extract_model_id(chat_instance)

      # Extract prompt metadata from the chat's agent (if available)
      prompt_metadata = extract_prompt_metadata(chat_instance)

      generation = trace.create_generation(
        name: "llm_call",
        metadata: @context.merge(kwargs.slice(:temperature, :max_tokens)),
        model: model_id,
        model_parameters: extract_model_parameters(kwargs),
        **prompt_metadata
      )

      messages_snapshot = capture_messages(chat_instance)
      generation.set_input(user_message, messages: messages_snapshot)

      call_start_time = Time.current
      result = @original_ask_method.call(*args, **kwargs, &block)

      finalize_generation(generation, result, call_start_time)

      if is_ephemeral_trace
        link_trace_to_message(trace, chat_instance, call_start_time)
        trace.finalize(output: result.content)
        @current_trace = nil
      end

      result
    rescue StandardError => e
      handle_error(e, trace, generation)
      raise
    end

    def setup_event_handlers
      setup_tool_call_handler
      setup_tool_result_handler
      setup_message_handlers
    end

    def setup_tool_call_handler
      instrumenter = self

      chat.on_tool_call do |tool_call|
        instrumenter.send(:handle_tool_call, tool_call)
      end
    end

    def setup_tool_result_handler
      instrumenter = self

      chat.on_tool_result do |result|
        instrumenter.send(:handle_tool_result, result)
      end
    end

    def setup_message_handlers
      instrumenter = self

      chat.on_new_message do
        Rails.logger.debug "[Observability] New message started"
      end

      chat.on_end_message do |message|
        Rails.logger.debug "[Observability] Message completed: #{message.role}"
      end
    end

    def handle_tool_call(tool_call)
      return unless @current_trace

      @current_tool_span = @current_trace.create_span(
        name: "tool:#{tool_call.name}",
        metadata: {
          tool_name: tool_call.name,
          tool_call_id: tool_call.id,
          level: "INFO"
        },
        input: format_tool_arguments(tool_call.arguments)
      )

      Rails.logger.info "[Observability] Tool call started: #{tool_call.name}"
    end

    def handle_tool_result(result)
      return unless @current_trace && @current_tool_span

      @current_tool_span.finalize(
        output: format_tool_result(result)
      )

      Rails.logger.info "[Observability] Tool call completed: #{@current_tool_span.name}"
      @current_tool_span = nil
    end

    def finalize_generation(generation, result, call_start_time)
      usage = extract_usage(result)
      provider_metadata = extract_provider_metadata(result)
      finish_reason = extract_finish_reason(result)
      cost = calculate_cost(result)
      raw_response = extract_raw_response(result)

      generation.finalize(
        output: result.content,
        usage: usage,
        cost_usd: cost,
        finish_reason: finish_reason,
        completion_start_time: call_start_time,
        provider_metadata: provider_metadata,
        raw_response: raw_response
      )
    rescue StandardError => e
      Rails.logger.error "[Observability] Failed to finalize generation: #{e.message}"
      generation.finalize(
        output: result.content,
        usage: { input_tokens: result.input_tokens || 0, output_tokens: result.output_tokens || 0 }
      ) rescue nil
    end

    def handle_error(error, trace, generation)
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

      generation&.update(status_message: "FAILED", finish_reason: "error") rescue nil

      Rails.logger.error "[Observability] Error captured: #{error.class.name} - #{error.message}"
    end

    def extract_prompt_metadata(chat_instance)
      metadata = {}

      # Try to get the agent class from context
      agent_class = @context[:agent_class]

      if agent_class && agent_class.respond_to?(:prompt_metadata)
        metadata = agent_class.prompt_metadata
        Rails.logger.debug "[Observability] Extracted prompt metadata: #{metadata.inspect}"
      end

      metadata
    rescue StandardError => e
      Rails.logger.debug "[Observability] Could not extract prompt metadata: #{e.message}"
      {}
    end

    def extract_model_id(chat_instance)
      if chat_instance.respond_to?(:model)
        model = chat_instance.model
        if model.respond_to?(:model_id)
          model.model_id
        elsif model.respond_to?(:id)
          model.id
        else
          model.to_s
        end
      else
        "unknown"
      end
    end

    def extract_model_parameters(kwargs)
      kwargs.slice(
        :temperature,
        :max_tokens,
        :top_p,
        :frequency_penalty,
        :presence_penalty,
        :stop,
        :response_format,
        :seed
      ).compact
    end

    def capture_messages(chat_instance)
      return [] unless chat_instance.respond_to?(:messages)
      return [] unless chat_instance.messages.respond_to?(:map)

      chat_instance.messages.map do |msg|
        {
          role: msg.role.to_s,
          content: truncate_content(msg.content)
        }
      end
    rescue StandardError => e
      Rails.logger.warn "[Observability] Failed to capture messages: #{e.message}"
      []
    end

    def extract_usage(result)
      usage = {
        input_tokens: result.input_tokens || 0,
        output_tokens: result.output_tokens || 0,
        total_tokens: (result.input_tokens || 0) + (result.output_tokens || 0)
      }

      if result.respond_to?(:raw) && result.raw.respond_to?(:body)
        raw_body = result.raw.body

        if raw_body.is_a?(Hash) && raw_body["usage"]
          raw_usage = raw_body["usage"]

          if raw_usage["prompt_tokens_details"]
            cached = raw_usage["prompt_tokens_details"]["cached_tokens"]
            usage[:cached_input_tokens] = cached if cached && cached > 0
          end

          if raw_usage["completion_tokens_details"]
            reasoning = raw_usage["completion_tokens_details"]["reasoning_tokens"]
            usage[:reasoning_tokens] = reasoning if reasoning && reasoning > 0
          end
        end
      end

      usage
    end

    def extract_provider_metadata(result)
      metadata = {}

      return metadata unless result.respond_to?(:raw) && result.raw

      raw = result.raw

      if raw.respond_to?(:body) && raw.body.is_a?(Hash)
        body = raw.body
        metadata[:request_id] = body["id"] if body["id"]
        metadata[:system_fingerprint] = body["system_fingerprint"] if body["system_fingerprint"]
        metadata[:model_version] = body["model"] if body["model"]
      end

      if raw.respond_to?(:headers) && raw.headers
        headers = raw.headers
        metadata[:x_request_id] = headers["x-request-id"] if headers["x-request-id"]
        metadata[:processing_ms] = headers["openai-processing-ms"].to_i if headers["openai-processing-ms"]
        metadata[:ratelimit_remaining_requests] = headers["x-ratelimit-remaining-requests"].to_i if headers["x-ratelimit-remaining-requests"]
        metadata[:ratelimit_remaining_tokens] = headers["x-ratelimit-remaining-tokens"].to_i if headers["x-ratelimit-remaining-tokens"]
      end

      metadata[:model_id] = result.model_id if result.respond_to?(:model_id)

      metadata.compact
    end

    def extract_finish_reason(result)
      return nil unless result.respond_to?(:raw) && result.raw
      return nil unless result.raw.respond_to?(:body) && result.raw.body.is_a?(Hash)

      raw_body = result.raw.body
      raw_body.dig("choices", 0, "finish_reason")
    end

    def calculate_cost(result)
      return 0.0 unless result.respond_to?(:model_id) && result.model_id

      model_info = RubyLLM.models.find(result.model_id)
      return 0.0 unless model_info&.input_price_per_million

      input_tokens = result.input_tokens || 0
      output_tokens = result.output_tokens || 0

      input_cost = input_tokens * model_info.input_price_per_million / 1_000_000.0
      output_cost = output_tokens * model_info.output_price_per_million / 1_000_000.0

      (input_cost + output_cost).round(6)
    rescue StandardError => e
      Rails.logger.warn "[Observability] Failed to calculate cost: #{e.message}"
      0.0
    end

    def extract_raw_response(result)
      return nil unless result.respond_to?(:raw) && result.raw

      raw_data = {}
      raw = result.raw

      raw_data[:status] = raw.status if raw.respond_to?(:status)

      if raw.respond_to?(:body)
        if raw.body.is_a?(Hash)
          raw_data[:body] = truncate_large_hash(raw.body)
        elsif raw.body.is_a?(String)
          begin
            parsed = JSON.parse(raw.body)
            raw_data[:body] = truncate_large_hash(parsed)
          rescue JSON::ParserError
            raw_data[:body] = raw.body[0..1000]
          end
        end
      end

      raw_data[:headers] = extract_relevant_headers(raw.headers) if raw.respond_to?(:headers)

      raw_data.empty? ? nil : raw_data
    end

    def extract_relevant_headers(headers)
      return {} unless headers

      relevant = {}
      interesting_headers = %w[
        x-request-id
        openai-processing-ms
        x-ratelimit-remaining-requests
        x-ratelimit-remaining-tokens
        x-ratelimit-limit-requests
        x-ratelimit-limit-tokens
        openai-organization
        openai-version
        content-type
      ]

      interesting_headers.each do |header|
        value = headers[header] || headers[header.downcase]
        relevant[header] = value if value
      end

      relevant
    end

    def format_input(message, attachments)
      input = { text: message }

      if attachments
        attachment_array = Array(attachments)
        input[:attachments] = attachment_array.map do |att|
          if att.is_a?(String)
            { path: att }
          else
            { type: att.class.name }
          end
        end
      end

      input
    end

    def format_tool_arguments(arguments)
      return arguments if arguments.is_a?(Hash) && arguments.size < 100

      arguments.to_json
    rescue StandardError
      arguments.to_s
    end

    def format_tool_result(result)
      case result
      when Hash
        truncate_large_hash(result)
      when String
        truncate_content(result)
      when RubyLLM::Content
        {
          text: truncate_content(result.text),
          has_attachments: result.attachments.present?
        }
      else
        result.to_s[0..5000]
      end
    end

    def truncate_content(content, max_length: 10_000)
      return nil if content.nil?
      return content if content.length <= max_length

      "#{content[0...max_length]}... [truncated, original length: #{content.length}]"
    end

    def truncate_large_hash(hash)
      hash.transform_values do |value|
        if value.is_a?(String) && value.length > 10_000
          truncate_content(value)
        elsif value.is_a?(Hash)
          truncate_large_hash(value)
        elsif value.is_a?(Array) && value.size > 100
          value[0..99] + [ "... #{value.size - 100} more items" ]
        else
          value
        end
      end
    end

    def link_trace_to_message(trace, chat_instance, call_start_time)
      return unless chat_instance.respond_to?(:messages)

      assistant_message = chat_instance.messages
        .where(role: "assistant")
        .where("created_at >= ?", call_start_time)
        .order(created_at: :desc)
        .first

      if assistant_message
        trace.update(message_id: assistant_message.id)
        Rails.logger.info "[Observability] Linked trace #{trace.trace_id} to message #{assistant_message.id}"
      end
    rescue StandardError => e
      Rails.logger.warn "[Observability] Failed to link trace to message: #{e.message}"
    end
  end
end
