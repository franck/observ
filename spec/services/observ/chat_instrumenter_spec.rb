require 'rails_helper'

RSpec.describe Observ::ChatInstrumenter do
  let(:session) { create(:observ_session) }
  let(:chat) do
    chat_double = double('Chat', id: 1, model: double(id: 'gpt-4o-mini'))
    allow(chat_double).to receive(:ask)
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

    it 'wraps the ask method' do
      expect(instrumenter).to receive(:wrap_ask_method)
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
      it 'extracts relevant parameters from kwargs' do
        kwargs = {
          temperature: 0.7,
          max_tokens: 100,
          top_p: 0.9,
          irrelevant: 'param'
        }

        params = instrumenter.send(:extract_model_parameters, kwargs)
        expect(params).to include(temperature: 0.7, max_tokens: 100, top_p: 0.9)
        expect(params).not_to have_key(:irrelevant)
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
  end
end
