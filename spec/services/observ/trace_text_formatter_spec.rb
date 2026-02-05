require 'rails_helper'

RSpec.describe Observ::TraceTextFormatter do
  let(:session) { create(:observ_session) }
  let(:trace) do
    create(:observ_trace, :finalized, :with_metrics,
      observ_session: session,
      name: 'chat_exchange',
      input: 'What is the capital of France?',
      output: 'The capital of France is Paris.',
      user_id: 'user123',
      tags: ['production', 'chat'],
      metadata: { phase: 'conversation', context: 'geography' }
    )
  end
  let(:formatter) { described_class.new(trace) }

  describe '#initialize' do
    it 'sets the trace' do
      expect(formatter.trace).to eq(trace)
    end
  end

  describe '#format' do
    context 'with a basic trace' do
      it 'includes trace header' do
        output = formatter.format
        expect(output).to include('TRACE: chat_exchange')
        expect(output).to include('=' * 80)
      end

      it 'includes trace ID' do
        output = formatter.format
        expect(output).to include("Trace ID: #{trace.trace_id}")
      end

      it 'includes start and end times' do
        output = formatter.format
        expect(output).to include('Start Time:')
        expect(output).to include('End Time:')
        expect(output).to include('UTC')
      end

      it 'includes duration' do
        output = formatter.format
        expect(output).to include('Duration:')
        expect(output).to include('ms')
      end

      it 'includes cost and tokens' do
        output = formatter.format
        expect(output).to include('Total Cost:')
        expect(output).to include('Total Tokens:')
      end

      it 'includes input and output' do
        output = formatter.format
        expect(output).to include('Input:')
        expect(output).to include('What is the capital of France?')
        expect(output).to include('Output:')
        expect(output).to include('The capital of France is Paris.')
      end

      it 'includes metadata' do
        output = formatter.format
        expect(output).to include('Metadata:')
        expect(output).to include('phase')
        expect(output).to include('conversation')
      end

      it 'includes tags' do
        output = formatter.format
        expect(output).to include('Tags:')
        expect(output).to include('production')
        expect(output).to include('chat')
      end

      it 'includes user_id when present' do
        output = formatter.format
        expect(output).to include('User ID: user123')
      end
    end

    context 'with trace annotations' do
      before do
        create(:observ_annotation,
          annotatable: trace,
          content: 'This is a good response',
          annotator: 'reviewer',
          tags: ['approved']
        )
        create(:observ_annotation,
          annotatable: trace,
          content: 'Follow-up needed',
          annotator: 'analyst'
        )
      end

      it 'includes annotations count' do
        output = formatter.format
        expect(output).to include('--- ANNOTATIONS (2) ---')
      end

      it 'includes annotation details' do
        output = formatter.format
        expect(output).to include('This is a good response')
        expect(output).to include('reviewer')
        expect(output).to include('Follow-up needed')
        expect(output).to include('analyst')
      end

      it 'includes annotation tags when present' do
        output = formatter.format
        expect(output).to include('approved')
      end
    end

    context 'with observations' do
      let!(:generation) do
        create(:observ_generation, :finalized, :with_metadata,
          trace: trace,
          name: 'llm_call',
          model: 'gpt-4',
          input: 'User query',
          output: 'LLM response',
          usage: {
            input_tokens: 150,
            output_tokens: 100,
            total_tokens: 250
          },
          cost_usd: 0.001200,
          finish_reason: 'stop',
          model_parameters: { temperature: 0.7, max_tokens: 500 }
        )
      end

      let!(:span) do
        create(:observ_span, :finalized,
          trace: trace,
          name: 'tool:search',
          input: { query: 'test' }.to_json,
          output: { result: 'success' }.to_json
        )
      end

      it 'includes observations section' do
        output = formatter.format
        expect(output).to include('OBSERVATIONS')
        expect(output).to include('(2)')
      end

      it 'includes generation details' do
        output = formatter.format
        expect(output).to include('[GENERATION] llm_call')
        expect(output).to include('Model: gpt-4')
        expect(output).to include('Cost: $0.001200')
        expect(output).to include('Usage:')
        expect(output).to include('Input tokens: 150')
        expect(output).to include('Output tokens: 100')
        expect(output).to include('Total tokens: 250')
        expect(output).to include('Finish Reason: stop')
      end

      it 'includes generation input and output' do
        output = formatter.format
        expect(output).to include('User query')
        expect(output).to include('LLM response')
      end

      it 'includes model parameters' do
        output = formatter.format
        expect(output).to include('Model Parameters:')
        expect(output).to include('temperature: 0.7')
        expect(output).to include('max_tokens: 500')
      end

      it 'includes span details' do
        output = formatter.format
        expect(output).to include('[SPAN] tool:search')
        expect(output).to include('"query": "test"')
        expect(output).to include('"result": "success"')
      end

      it 'includes observation IDs' do
        output = formatter.format
        expect(output).to include("Observation ID: #{generation.observation_id}")
        expect(output).to include("Observation ID: #{span.observation_id}")
      end

      it 'includes observation timestamps' do
        output = formatter.format
        expect(output).to include('Start:')
        expect(output).to include('End:')
        expect(output).to include('Duration:')
      end

      it 'uses box drawing characters for structure' do
        output = formatter.format
        expect(output).to include('┌─')
        expect(output).to include('└─')
        expect(output).to include('│')
      end
    end

    context 'with nested observations' do
      let!(:parent_generation) do
        create(:observ_generation, :finalized,
          trace: trace,
          name: 'parent_llm'
        )
      end

      let!(:child_span) do
        create(:observ_span, :finalized,
          trace: trace,
          name: 'child_tool',
          parent_observation_id: parent_generation.observation_id
        )
      end

      it 'shows hierarchical structure' do
        output = formatter.format
        expect(output).to include('CHILD OBSERVATIONS')
      end

      it 'indents child observations' do
        output = formatter.format
        parent_index = output.index('[GENERATION] parent_llm')
        child_index = output.index('[SPAN] child_tool')
        expect(parent_index).to be < child_index
        expect(output).to include('└─ END CHILD OBSERVATIONS')
      end
    end



    context 'with no observations' do
      it 'shows appropriate message' do
        output = formatter.format
        expect(output).to include('No observations recorded.')
      end
    end

    context 'with long content' do
      let(:long_content) { 'a' * 15000 }
      let(:trace) do
        create(:observ_trace,
          observ_session: session,
          input: long_content
        )
      end

      it 'truncates long content' do
        output = formatter.format
        expect(output).to include('Content truncated')
        expect(output).to include('original length: 15000')
      end
    end

    context 'with JSON input/output' do
      let(:json_input) { { query: 'test', params: { limit: 10 } }.to_json }
      let(:trace) do
        create(:observ_trace,
          observ_session: session,
          input: json_input
        )
      end

      it 'pretty prints JSON' do
        output = formatter.format
        expect(output).to include('"query"')
        expect(output).to include('"params"')
        # Pretty printed JSON should have newlines
        expect(JSON.parse(json_input)).to be_a(Hash)
      end
    end

    context 'with generation messages' do
      let!(:generation) do
        create(:observ_generation, :finalized,
          trace: trace,
          messages: [
            { 'role' => 'user', 'content' => 'Hello' },
            { 'role' => 'assistant', 'content' => 'Hi there!' }
          ]
        )
      end

      it 'includes messages section' do
        output = formatter.format
        expect(output).to include('Messages:')
        expect(output).to include('[1] user:')
        expect(output).to include('[2] assistant:')
      end
    end

    context 'with generation tools' do
      let!(:generation) do
        create(:observ_generation, :finalized,
          trace: trace,
          tools: [
            { 'name' => 'search' },
            { 'name' => 'calculator' },
            { 'name' => 'database' }
          ]
        )
      end

      it 'includes tools section' do
        output = formatter.format
        expect(output).to include('Tools Available: 3')
        expect(output).to include('search')
        expect(output).to include('calculator')
        expect(output).to include('database')
      end
    end

    context 'with cached tokens' do
      let!(:generation) do
        create(:observ_generation, :with_cached_tokens, :finalized,
          trace: trace
        )
      end

      it 'includes cached token information' do
        output = formatter.format
        expect(output).to include('Cached input tokens: 25')
      end
    end

    context 'with reasoning tokens' do
      let!(:generation) do
        create(:observ_generation, :with_reasoning_tokens, :finalized,
          trace: trace
        )
      end

      it 'includes reasoning token information' do
        output = formatter.format
        expect(output).to include('Reasoning tokens: 20')
      end
    end

    context 'with provider metadata' do
      let!(:generation) do
        create(:observ_generation, :with_metadata, :finalized,
          trace: trace
        )
      end

      it 'includes provider metadata section' do
        output = formatter.format
        expect(output).to include('Provider Metadata:')
        expect(output).to include('request_id')
      end
    end
  end

  describe 'private methods' do
    describe '#format_time' do
      it 'formats time in UTC' do
        time = Time.parse('2025-11-06 10:30:00 UTC')
        result = formatter.send(:format_time, time)
        expect(result).to eq('2025-11-06 10:30:00 UTC')
      end

      it 'returns N/A for nil time' do
        result = formatter.send(:format_time, nil)
        expect(result).to eq('N/A')
      end
    end

    describe '#format_duration' do
      it 'formats duration in milliseconds' do
        result = formatter.send(:format_duration, 1234.56)
        expect(result).to eq('1234.56ms')
      end

      it 'returns N/A for nil duration' do
        result = formatter.send(:format_duration, nil)
        expect(result).to eq('N/A')
      end
    end

    describe '#format_cost' do
      it 'formats cost with 6 decimal places' do
        result = formatter.send(:format_cost, 0.001234)
        expect(result).to eq('$0.001234')
      end

      it 'returns $0.000000 for nil cost' do
        result = formatter.send(:format_cost, nil)
        expect(result).to eq('$0.000000')
      end
    end

    describe '#truncate_content' do
      it 'returns content as-is when under limit' do
        content = 'a' * 5000
        result = formatter.send(:truncate_content, content)
        expect(result).to eq(content)
      end

      it 'truncates content when over limit' do
        content = 'a' * 15000
        result = formatter.send(:truncate_content, content)
        expect(result).to include('Content truncated')
        expect(result).to include('original length: 15000')
      end

      it 'returns empty string for nil content' do
        result = formatter.send(:truncate_content, nil)
        expect(result).to eq('')
      end
    end

    describe '#format_json' do
      it 'pretty prints valid JSON objects' do
        obj = { key: 'value', nested: { data: 123 } }
        result = formatter.send(:format_json, obj)
        expect(result).to include('"key"')
        expect(result).to include('"value"')
        expect(result).to include("\n") # Pretty printed should have newlines
      end

      it 'handles objects that cannot be converted to JSON' do
        obj = double('UnserializableObject')
        allow(obj).to receive(:to_s).and_return('custom_string')
        allow(JSON).to receive(:pretty_generate).with(obj).and_raise(StandardError)
        result = formatter.send(:format_json, obj)
        expect(result).to eq('custom_string')
      end
    end
  end

  describe 'integration test' do
    let!(:generation) do
      create(:observ_generation, :finalized, :with_metadata,
        trace: trace,
        name: 'main_llm',
        model: 'gpt-4',
        usage: { input_tokens: 100, output_tokens: 50, total_tokens: 150 },
        cost_usd: 0.001
      )
    end

    let!(:span) do
      create(:observ_span, :finalized,
        trace: trace,
        name: 'tool_execution',
        parent_observation_id: generation.observation_id
      )
    end

    before do
      create(:observ_annotation,
        annotatable: trace,
        content: 'Trace annotation'
      )
    end

    it 'produces a complete, well-formatted output' do
      output = formatter.format

      # Verify main sections exist
      expect(output).to include('TRACE: chat_exchange')
      expect(output).to include('OBSERVATIONS')

      # Verify trace details
      expect(output).to include('Trace ID:')
      expect(output).to include('Total Cost:')
      expect(output).to include('Total Tokens:')

      # Verify trace annotation
      expect(output).to include('Trace annotation')

      # Verify observations
      expect(output).to include('[GENERATION] main_llm')
      expect(output).to include('[SPAN] tool_execution')

      # Verify hierarchy
      expect(output).to include('CHILD OBSERVATIONS')

      # Verify box drawing characters
      expect(output).to include('┌─')
      expect(output).to include('└─')
      expect(output).to include('│')

      # Verify it's valid text (no binary characters or corruption)
      expect(output.encoding).to eq(Encoding::UTF_8)
    end
  end
end
