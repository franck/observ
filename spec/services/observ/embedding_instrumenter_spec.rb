require 'rails_helper'

RSpec.describe Observ::EmbeddingInstrumenter do
  let(:session) { create(:observ_session) }
  let(:instrumenter) { described_class.new(session, context: { operation: 'test' }) }

  # Mock RubyLLM.embed response
  let(:mock_embedding_result) do
    double(
      'EmbeddingResult',
      vectors: Array.new(1536) { rand },
      model: 'text-embedding-3-small',
      input_tokens: 10
    )
  end

  let(:mock_batch_embedding_result) do
    double(
      'BatchEmbeddingResult',
      vectors: [Array.new(1536) { rand }, Array.new(1536) { rand }, Array.new(1536) { rand }],
      model: 'text-embedding-3-small',
      input_tokens: 30
    )
  end

  before do
    # Store the original method
    @original_embed = RubyLLM.method(:embed) if RubyLLM.respond_to?(:embed)

    # Mock the RubyLLM.embed method
    allow(RubyLLM).to receive(:embed).and_return(mock_embedding_result)

    # Mock RubyLLM.config
    config_double = double('Config', default_embedding_model: 'text-embedding-3-small')
    allow(config_double).to receive(:respond_to?).with(:default_embedding_model).and_return(true)
    allow(RubyLLM).to receive(:config).and_return(config_double)

    # Mock RubyLLM.models
    model_info = double(
      'ModelInfo',
      input_price_per_million: 20.0,
      output_price_per_million: 0.0
    )
    models_double = double('Models')
    allow(models_double).to receive(:find).and_return(model_info)
    allow(RubyLLM).to receive(:models).and_return(models_double)
  end

  after do
    # Restore the original method if it existed
    if @original_embed
      RubyLLM.define_singleton_method(:embed, @original_embed)
    end
  end

  describe '#initialize' do
    it 'sets session and context' do
      expect(instrumenter.session).to eq(session)
      expect(instrumenter.context).to eq({ operation: 'test' })
    end
  end

  describe '#instrument!' do
    it 'sets instrumented flag' do
      instrumenter.instrument!
      expect(instrumenter.instance_variable_get(:@instrumented)).to be true
    end

    it 'only instruments once' do
      instrumenter.instrument!
      expect(instrumenter).not_to receive(:wrap_embed_method)
      instrumenter.instrument!
    end

    it 'logs instrumentation message' do
      expect(Rails.logger).to receive(:info).with(/Instrumented RubyLLM.embed/)
      instrumenter.instrument!
    end
  end

  describe '#uninstrument!' do
    it 'restores original method' do
      instrumenter.instrument!
      instrumenter.uninstrument!
      expect(instrumenter.instance_variable_get(:@instrumented)).to be false
    end

    it 'does nothing if not instrumented' do
      expect(Rails.logger).not_to receive(:info).with(/Uninstrumented/)
      instrumenter.uninstrument!
    end
  end

  describe 'embed call instrumentation' do
    before do
      instrumenter.instrument!
    end

    after do
      instrumenter.uninstrument!
    end

    it 'creates a trace for each embed call' do
      expect {
        RubyLLM.embed("Test text")
      }.to change(session.traces, :count).by(1)
    end

    it 'creates an embedding observation for each call' do
      RubyLLM.embed("Test text")
      trace = session.traces.last
      expect(trace.embeddings.count).to eq(1)
    end

    it 'records the model used' do
      RubyLLM.embed("Test text")
      embedding = session.traces.last.embeddings.first
      expect(embedding.model).to eq('text-embedding-3-small')
    end

    it 'records input tokens in usage' do
      RubyLLM.embed("Test text")
      embedding = session.traces.last.embeddings.first
      expect(embedding.usage['input_tokens']).to eq(10)
    end

    it 'calculates cost' do
      RubyLLM.embed("Test text")
      embedding = session.traces.last.embeddings.first
      # 10 tokens * 20 / 1_000_000 = 0.0002
      expect(embedding.cost_usd).to eq(0.0002)
    end

    it 'records dimensions in metadata' do
      RubyLLM.embed("Test text")
      embedding = session.traces.last.embeddings.first
      expect(embedding.dimensions).to eq(1536)
    end

    it 'returns the original result' do
      result = RubyLLM.embed("Test text")
      expect(result).to eq(mock_embedding_result)
    end

    it 'includes context in trace metadata' do
      RubyLLM.embed("Test text")
      trace = session.traces.last
      expect(trace.metadata).to include('operation' => 'test')
    end
  end

  describe 'batch embedding instrumentation' do
    before do
      allow(RubyLLM).to receive(:embed).and_return(mock_batch_embedding_result)
      instrumenter.instrument!
    end

    after do
      instrumenter.uninstrument!
    end

    it 'records batch size' do
      RubyLLM.embed(["Text 1", "Text 2", "Text 3"])
      embedding = session.traces.last.embeddings.first
      expect(embedding.batch_size).to eq(3)
    end

    it 'records vectors count' do
      RubyLLM.embed(["Text 1", "Text 2", "Text 3"])
      embedding = session.traces.last.embeddings.first
      expect(embedding.vectors_count).to eq(3)
    end

    it 'records correct input tokens for batch' do
      RubyLLM.embed(["Text 1", "Text 2", "Text 3"])
      embedding = session.traces.last.embeddings.first
      expect(embedding.input_tokens).to eq(30)
    end
  end

  describe 'error handling' do
    before do
      allow(RubyLLM).to receive(:embed).and_raise(StandardError.new("API Error"))
      instrumenter.instrument!
    end

    after do
      instrumenter.uninstrument!
    end

    it 'creates an error span on failure' do
      expect {
        RubyLLM.embed("Test text") rescue nil
      }.to change(session.traces, :count).by(1)

      trace = session.traces.last
      error_span = trace.spans.find_by(name: 'error')
      expect(error_span).to be_present
      expect(error_span.metadata['error_type']).to eq('StandardError')
    end

    it 'raises the original error' do
      expect {
        RubyLLM.embed("Test text")
      }.to raise_error(StandardError, "API Error")
    end

    it 'marks embedding as failed' do
      RubyLLM.embed("Test text") rescue nil
      embedding = session.traces.last.embeddings.first
      expect(embedding.status_message).to eq('FAILED')
    end
  end

  describe 'cost calculation' do
    before do
      instrumenter.instrument!
    end

    after do
      instrumenter.uninstrument!
    end

    it 'returns 0 when model info not found' do
      allow(RubyLLM.models).to receive(:find).and_return(nil)
      RubyLLM.embed("Test text")
      embedding = session.traces.last.embeddings.first
      expect(embedding.cost_usd).to eq(0.0)
    end

    it 'handles missing input_price_per_million' do
      model_info = double('ModelInfo', input_price_per_million: nil)
      allow(RubyLLM.models).to receive(:find).and_return(model_info)
      RubyLLM.embed("Test text")
      embedding = session.traces.last.embeddings.first
      expect(embedding.cost_usd).to eq(0.0)
    end
  end

  describe 'trace aggregation' do
    before do
      instrumenter.instrument!
    end

    after do
      instrumenter.uninstrument!
    end

    it 'updates trace total_cost' do
      RubyLLM.embed("Test text")
      trace = session.traces.last
      expect(trace.total_cost).to be > 0
    end

    it 'updates trace total_tokens' do
      RubyLLM.embed("Test text")
      trace = session.traces.last
      expect(trace.total_tokens).to eq(10)
    end
  end
end
