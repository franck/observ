require 'rails_helper'

RSpec.describe Observ::Generation, type: :model do
  describe '#set_input' do
    let(:generation) { create(:observ_generation) }

    it 'updates input field' do
      generation.set_input('test input')
      expect(generation.input).to eq('test input')
    end

    it 'converts hash input to JSON' do
      generation.set_input({ message: 'hello' })
      expect(generation.input).to be_a(String)
      expect(JSON.parse(generation.input)).to eq({ 'message' => 'hello' })
    end

    it 'sets messages when provided' do
      messages = [ { role: 'user', content: 'hello' } ]
      generation.set_input('test', messages: messages)
      expect(generation.messages).to eq([ { 'role' => 'user', 'content' => 'hello' } ])
    end
  end

  describe '#finalize' do
    let(:generation) { create(:observ_generation) }

    it 'sets all generation-specific fields' do
      usage = { input_tokens: 50, output_tokens: 50, total_tokens: 100 }
      provider_metadata = { request_id: 'req_123' }

      generation.finalize(
        output: 'response text',
        usage: usage,
        cost_usd: 0.001,
        finish_reason: 'stop',
        provider_metadata: provider_metadata
      )

      expect(generation.output).to eq('response text')
      expect(generation.usage['total_tokens']).to eq(100)
      expect(generation.cost_usd).to eq(0.001)
      expect(generation.finish_reason).to eq('stop')
      expect(generation.provider_metadata['request_id']).to eq('req_123')
      expect(generation.end_time).to be_present
    end

    it 'merges usage with existing usage' do
      generation.usage = { existing: 'data' }
      generation.finalize(
        output: 'test',
        usage: { new: 'data' }
      )
      expect(generation.usage).to include('existing' => 'data', 'new' => 'data')
    end

    it 'converts hash output to JSON' do
      generation.finalize(output: { result: 'success' })
      expect(generation.output).to be_a(String)
      expect(JSON.parse(generation.output)).to eq({ 'result' => 'success' })
    end
  end

  describe '#time_to_first_token_ms' do
    let(:generation) { create(:observ_generation) }

    it 'returns nil when completion_start_time is not set' do
      expect(generation.time_to_first_token_ms).to be_nil
    end

    it 'calculates time to first token' do
      start = Time.current
      generation.start_time = start
      generation.completion_start_time = start + 0.5.seconds
      generation.save

      expect(generation.time_to_first_token_ms).to eq(500.0)
    end
  end

  describe '#total_tokens' do
    it 'returns total_tokens from usage' do
      generation = create(:observ_generation, usage: { total_tokens: 150 })
      expect(generation.total_tokens).to eq(150)
    end

    it 'returns 0 when usage is empty' do
      generation = create(:observ_generation, usage: {})
      expect(generation.total_tokens).to eq(0)
    end
  end

  describe '#input_tokens' do
    it 'returns input_tokens from usage' do
      generation = create(:observ_generation, usage: { input_tokens: 75 })
      expect(generation.input_tokens).to eq(75)
    end
  end

  describe '#output_tokens' do
    it 'returns output_tokens from usage' do
      generation = create(:observ_generation, usage: { output_tokens: 75 })
      expect(generation.output_tokens).to eq(75)
    end
  end

  describe 'cached tokens' do
    it 'stores and retrieves cached_input_tokens' do
      generation = create(:observ_generation, :with_cached_tokens)
      expect(generation.usage['cached_input_tokens']).to eq(25)
    end
  end

  describe 'reasoning tokens' do
    it 'stores and retrieves reasoning_tokens' do
      generation = create(:observ_generation, :with_reasoning_tokens)
      expect(generation.usage['reasoning_tokens']).to eq(20)
    end
  end
end
