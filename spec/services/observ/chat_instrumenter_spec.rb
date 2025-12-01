require 'rails_helper'

RSpec.describe Observ::ChatInstrumenter do
  let(:session) { create(:observ_session) }
  let(:chat) do
    chat_double = double('Chat', id: 1, model: double(id: 'gpt-4o-mini'))
    allow(chat_double).to receive(:ask)
    allow(chat_double).to receive(:complete)
    allow(chat_double).to receive(:on_tool_call)
    allow(chat_double).to receive(:on_tool_result)
    allow(chat_double).to receive(:on_new_message)
    allow(chat_double).to receive(:on_end_message)
    chat_double
  end
  let(:instrumenter) { described_class.new(session, chat, context: { phase: 'test' }) }

  describe '#initialize' do
    it 'sets session, chat, and context' do
      expect(instrumenter.session).to eq(session)
      expect(instrumenter.chat).to eq(chat)
      expect(instrumenter.instance_variable_get(:@context)).to eq({ phase: 'test' })
    end

    it 'initializes with empty current_trace and current_tool_span' do
      expect(instrumenter.current_trace).to be_nil
      expect(instrumenter.current_tool_span).to be_nil
    end
  end

  describe '#instrument!' do
    it 'sets instrumented flag' do
      instrumenter.instrument!
      expect(instrumenter.instance_variable_get(:@instrumented)).to be true
    end

    it 'wraps the ask and complete methods' do
      expect(instrumenter).to receive(:wrap_ask_method)
      expect(instrumenter).to receive(:wrap_complete_method)
      expect(instrumenter).to receive(:setup_event_handlers)
      instrumenter.instrument!
    end

    it 'only instruments once' do
      instrumenter.instrument!
      expect(instrumenter).not_to receive(:wrap_ask_method)
      instrumenter.instrument!
    end
  end

  describe '#create_trace' do
    it 'creates a trace associated with the session' do
      expect {
        instrumenter.create_trace(name: 'test', input: 'input')
      }.to change(session.traces, :count).by(1)
    end

    it 'sets current_trace' do
      trace = instrumenter.create_trace(name: 'test')
      expect(instrumenter.current_trace).to eq(trace)
    end

    it 'merges context into trace metadata' do
      trace = instrumenter.create_trace(name: 'test', metadata: { extra: 'data' })
      expect(trace.metadata).to include('phase' => 'test', 'extra' => 'data')
    end
  end

  describe '#finalize_current_trace' do
    it 'finalizes and clears current_trace' do
      trace = instrumenter.create_trace(name: 'test')
      instrumenter.finalize_current_trace(output: 'done')

      expect(trace.reload.end_time).to be_present
      expect(trace.output).to eq('done')
      expect(instrumenter.current_trace).to be_nil
    end

    it 'does nothing when current_trace is nil' do
      expect {
        instrumenter.finalize_current_trace(output: 'done')
      }.not_to raise_error
    end
  end

  describe 'private methods' do
    describe '#extract_model_id' do
      it 'extracts model id from chat' do
        model_id = instrumenter.send(:extract_model_id, chat)
        expect(model_id).to eq('gpt-4o-mini')
      end

      it 'returns unknown when chat has no model' do
        chat_without_model = double('Chat', id: 1)
        allow(chat_without_model).to receive(:respond_to?).with(:model).and_return(false)
        model_id = instrumenter.send(:extract_model_id, chat_without_model)
        expect(model_id).to eq('unknown')
      end
    end

    describe '#extract_model_parameters' do
      it 'extracts relevant parameters from internal RubyLLM chat object' do
        llm_chat = double('RubyLLM::Chat',
          params: {
            temperature: 0.7,
            max_tokens: 100,
            top_p: 0.9,
            irrelevant: 'param'
          }
        )

        chat_instance = double('Chat')
        allow(chat_instance).to receive(:instance_variable_get).with(:@chat).and_return(llm_chat)

        params = instrumenter.send(:extract_model_parameters, chat_instance)
        expect(params).to include(temperature: 0.7, max_tokens: 100, top_p: 0.9)
        expect(params).not_to have_key(:irrelevant)
      end

      it 'returns empty hash when chat has no internal @chat object' do
        chat_without_llm = double('Chat')
        allow(chat_without_llm).to receive(:instance_variable_get).with(:@chat).and_return(nil)

        params = instrumenter.send(:extract_model_parameters, chat_without_llm)
        expect(params).to eq({})
      end

      it 'returns empty hash when params is nil' do
        llm_chat = double('RubyLLM::Chat', params: nil)
        chat_instance = double('Chat')
        allow(chat_instance).to receive(:instance_variable_get).with(:@chat).and_return(llm_chat)

        params = instrumenter.send(:extract_model_parameters, chat_instance)
        expect(params).to eq({})
      end

      it 'extracts params via instance variable if params method not available' do
        llm_chat = double('RubyLLM::Chat')
        allow(llm_chat).to receive(:respond_to?).with(:params).and_return(false)
        allow(llm_chat).to receive(:instance_variable_defined?).with(:@params).and_return(true)
        allow(llm_chat).to receive(:instance_variable_get).with(:@params).and_return({ temperature: 0.5 })

        chat_instance = double('Chat')
        allow(chat_instance).to receive(:instance_variable_get).with(:@chat).and_return(llm_chat)

        params = instrumenter.send(:extract_model_parameters, chat_instance)
        expect(params).to include(temperature: 0.5)
      end
    end

    describe '#extract_usage' do
      let(:result) { double(input_tokens: 50, output_tokens: 50) }

      it 'extracts basic token usage' do
        usage = instrumenter.send(:extract_usage, result)
        expect(usage[:input_tokens]).to eq(50)
        expect(usage[:output_tokens]).to eq(50)
        expect(usage[:total_tokens]).to eq(100)
      end

      it 'handles nil tokens' do
        result = double(input_tokens: nil, output_tokens: nil)
        usage = instrumenter.send(:extract_usage, result)
        expect(usage[:input_tokens]).to eq(0)
        expect(usage[:output_tokens]).to eq(0)
        expect(usage[:total_tokens]).to eq(0)
      end
    end

    describe '#calculate_cost' do
      let(:result) { double(model_id: 'gpt-4o-mini', input_tokens: 100, output_tokens: 100) }

      it 'calculates cost using model registry' do
        model_info = double(
          input_price_per_million: 150,
          output_price_per_million: 600
        )
        allow(RubyLLM.models).to receive(:find).with('gpt-4o-mini').and_return(model_info)

        cost = instrumenter.send(:calculate_cost, result)
        expect(cost).to eq(0.075)  # (100*150 + 100*600) / 1_000_000
      end

      it 'returns 0 when model not found' do
        allow(RubyLLM.models).to receive(:find).and_return(nil)
        cost = instrumenter.send(:calculate_cost, result)
        expect(cost).to eq(0.0)
      end
    end

    describe '#truncate_content' do
      it 'returns content as-is when under limit' do
        content = 'a' * 5000
        result = instrumenter.send(:truncate_content, content)
        expect(result).to eq(content)
      end

      it 'truncates content when over limit' do
        content = 'a' * 15000
        result = instrumenter.send(:truncate_content, content)
        expect(result).to include('truncated')
        expect(result.length).to be < content.length
      end

      it 'returns nil for nil content' do
        result = instrumenter.send(:truncate_content, nil)
        expect(result).to be_nil
      end
    end

    describe '#format_input' do
      it 'formats text message with attachments' do
        input = instrumenter.send(:format_input, 'hello', [ 'file.txt' ])
        expect(input[:text]).to eq('hello')
        expect(input[:attachments]).to be_an(Array)
        expect(input[:attachments].first[:path]).to eq('file.txt')
      end

      it 'handles nil attachments' do
        input = instrumenter.send(:format_input, 'hello', nil)
        expect(input[:text]).to eq('hello')
        expect(input[:attachments]).to be_nil
      end
    end

    describe '#find_messages_by_role' do
      context 'with ActiveRecord relation (responds to :where)' do
        it 'uses where clause for filtering' do
          messages = double('Messages')
          filtered = double('FilteredMessages')
          expect(messages).to receive(:respond_to?).with(:where).and_return(true)
          expect(messages).to receive(:where).with(role: :user).and_return(filtered)

          result = instrumenter.send(:find_messages_by_role, messages, :user)
          expect(result).to eq(filtered)
        end
      end

      context 'with plain Array (raw RubyLLM::Chat messages)' do
        it 'uses select with role comparison' do
          msg1 = double('Message', role: :user)
          msg2 = double('Message', role: :assistant)
          msg3 = double('Message', role: 'user') # String role
          messages = [ msg1, msg2, msg3 ]

          result = instrumenter.send(:find_messages_by_role, messages, :user)
          expect(result).to eq([ msg1, msg3 ])
        end

        it 'handles symbol role parameter matching string roles' do
          msg1 = double('Message', role: 'assistant')
          msg2 = double('Message', role: :assistant)
          messages = [ msg1, msg2 ]

          result = instrumenter.send(:find_messages_by_role, messages, :assistant)
          expect(result).to eq([ msg1, msg2 ])
        end

        it 'handles string role parameter' do
          msg1 = double('Message', role: :user)
          msg2 = double('Message', role: 'user')
          messages = [ msg1, msg2 ]

          result = instrumenter.send(:find_messages_by_role, messages, 'user')
          expect(result).to eq([ msg1, msg2 ])
        end

        it 'returns empty array when no messages match' do
          msg1 = double('Message', role: :assistant)
          messages = [ msg1 ]

          result = instrumenter.send(:find_messages_by_role, messages, :user)
          expect(result).to eq([])
        end
      end
    end

    describe '#link_trace_to_message' do
      let(:trace) { instrumenter.create_trace(name: 'test') }
      let(:call_start_time) { Time.current }

      # Use Struct for message objects since they naturally respond_to? stubbed attributes
      let(:message_class) { Struct.new(:role, :id, keyword_init: true) }

      context 'with ActiveRecord-backed messages' do
        it 'uses ActiveRecord query methods and attempts to update trace' do
          assistant_message = message_class.new(role: 'assistant', id: 123)

          messages = double('Messages')
          query_chain = double('QueryChain')

          chat_instance = double('Chat')
          allow(chat_instance).to receive(:respond_to?).with(:messages).and_return(true)
          allow(chat_instance).to receive(:messages).and_return(messages)
          allow(messages).to receive(:respond_to?).with(:where).and_return(true)
          allow(messages).to receive(:where).with(role: "assistant").and_return(query_chain)
          allow(query_chain).to receive(:where).and_return(query_chain)
          allow(query_chain).to receive(:order).with(created_at: :desc).and_return(query_chain)
          allow(query_chain).to receive(:first).and_return(assistant_message)

          # Verify the trace.update is called with the message_id
          # (The actual update may fail due to FK constraint, but we verify the call is attempted)
          expect(trace).to receive(:update).with(message_id: 123)

          instrumenter.send(:link_trace_to_message, trace, chat_instance, call_start_time)
        end
      end

      context 'with plain Array messages (raw RubyLLM::Chat)' do
        it 'uses array filtering and attempts to update trace with last assistant message id' do
          msg1 = message_class.new(role: :user, id: 111)
          msg2 = message_class.new(role: :assistant, id: 456)
          msg3 = message_class.new(role: :assistant, id: 789)
          messages = [ msg1, msg2, msg3 ]

          chat_instance = double('Chat')
          allow(chat_instance).to receive(:respond_to?).with(:messages).and_return(true)
          allow(chat_instance).to receive(:messages).and_return(messages)

          # Verify the trace.update is called with the last assistant message id
          expect(trace).to receive(:update).with(message_id: 789)

          instrumenter.send(:link_trace_to_message, trace, chat_instance, call_start_time)
        end

        it 'does not update trace when message has no id method' do
          # Use a struct without id field
          msg_class_no_id = Struct.new(:role, keyword_init: true)
          msg1 = msg_class_no_id.new(role: :assistant)
          messages = [ msg1 ]

          chat_instance = double('Chat')
          allow(chat_instance).to receive(:respond_to?).with(:messages).and_return(true)
          allow(chat_instance).to receive(:messages).and_return(messages)

          # Should not attempt to update because message doesn't respond to :id
          expect(trace).not_to receive(:update)

          instrumenter.send(:link_trace_to_message, trace, chat_instance, call_start_time)
        end

        it 'does not update trace when message id is nil' do
          msg1 = message_class.new(role: :assistant, id: nil)
          messages = [ msg1 ]

          chat_instance = double('Chat')
          allow(chat_instance).to receive(:respond_to?).with(:messages).and_return(true)
          allow(chat_instance).to receive(:messages).and_return(messages)

          # Should not attempt to update because message.id is nil
          expect(trace).not_to receive(:update)

          instrumenter.send(:link_trace_to_message, trace, chat_instance, call_start_time)
        end
      end
    end
  end
end
