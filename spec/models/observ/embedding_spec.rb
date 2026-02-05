require 'rails_helper'

RSpec.describe Observ::Embedding, type: :model do
  describe '#set_input' do
    let(:embedding) { create(:observ_embedding) }

    it 'updates input field with string' do
      embedding.set_input('test input')
      expect(embedding.input).to eq('test input')
    end

    it 'converts array input to JSON' do
      embedding.set_input(['text 1', 'text 2'])
      expect(embedding.input).to be_a(String)
      expect(JSON.parse(embedding.input)).to eq(['text 1', 'text 2'])
    end
  end

  describe '#finalize' do
    let(:embedding) { create(:observ_embedding) }

    it 'sets all embedding-specific fields' do
      usage = { input_tokens: 25, total_tokens: 25 }

      embedding.finalize(
        output: { model: 'text-embedding-3-small', dimensions: 1536 },
        usage: usage,
        cost_usd: 0.000025
      )

      expect(JSON.parse(embedding.output)).to include('model' => 'text-embedding-3-small')
      expect(embedding.usage['input_tokens']).to eq(25)
      expect(embedding.cost_usd).to eq(0.000025)
      expect(embedding.end_time).to be_present
    end

    it 'merges usage with existing usage' do
      embedding.usage = { existing: 'data' }
      embedding.finalize(
        output: 'test',
        usage: { input_tokens: 10 }
      )
      expect(embedding.usage).to include('existing' => 'data', 'input_tokens' => 10)
    end

    it 'converts hash output to JSON' do
      embedding.finalize(output: { result: 'success' })
      expect(embedding.output).to be_a(String)
      expect(JSON.parse(embedding.output)).to eq({ 'result' => 'success' })
    end

    it 'sets status_message when provided' do
      embedding.finalize(output: 'test', status_message: 'COMPLETED')
      expect(embedding.status_message).to eq('COMPLETED')
    end
  end

  describe '#input_tokens' do
    it 'returns input_tokens from usage' do
      embedding = create(:observ_embedding, usage: { input_tokens: 75 })
      expect(embedding.input_tokens).to eq(75)
    end

    it 'returns 0 when usage is empty' do
      embedding = create(:observ_embedding, usage: {})
      expect(embedding.input_tokens).to eq(0)
    end
  end

  describe '#total_tokens' do
    it 'returns input_tokens as total (embeddings only have input)' do
      embedding = create(:observ_embedding, usage: { input_tokens: 100 })
      expect(embedding.total_tokens).to eq(100)
    end
  end

  describe '#batch_size' do
    it 'returns batch_size from metadata' do
      embedding = create(:observ_embedding, metadata: { batch_size: 5 })
      expect(embedding.batch_size).to eq(5)
    end

    it 'returns 1 when metadata is empty' do
      embedding = create(:observ_embedding, metadata: {})
      expect(embedding.batch_size).to eq(1)
    end
  end

  describe '#dimensions' do
    it 'returns dimensions from metadata' do
      embedding = create(:observ_embedding, metadata: { dimensions: 1536 })
      expect(embedding.dimensions).to eq(1536)
    end

    it 'returns nil when dimensions not set' do
      embedding = create(:observ_embedding, metadata: {})
      expect(embedding.dimensions).to be_nil
    end
  end

  describe '#vectors_count' do
    it 'returns vectors_count from metadata' do
      embedding = create(:observ_embedding, metadata: { vectors_count: 3 })
      expect(embedding.vectors_count).to eq(3)
    end

    it 'returns 1 when vectors_count not set' do
      embedding = create(:observ_embedding, metadata: {})
      expect(embedding.vectors_count).to eq(1)
    end
  end

  describe 'STI type' do
    it 'has the correct type' do
      embedding = create(:observ_embedding)
      expect(embedding.type).to eq('Observ::Embedding')
    end

    it 'is a subclass of Observation' do
      expect(Observ::Embedding.superclass).to eq(Observ::Observation)
    end
  end

  describe 'batch embedding' do
    let(:embedding) { create(:observ_embedding, :batch) }

    it 'has correct batch metadata' do
      expect(embedding.batch_size).to eq(3)
      expect(embedding.vectors_count).to eq(3)
    end

    it 'has correct usage for batch' do
      expect(embedding.input_tokens).to eq(30)
    end
  end
end
