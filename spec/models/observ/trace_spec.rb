require 'rails_helper'

RSpec.describe Observ::Trace, type: :model do
  describe 'associations' do
    it { should belong_to(:observ_session).class_name('Observ::Session') }
    it { should have_many(:observations).class_name('Observ::Observation').dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:trace_id) }
    it { should validate_presence_of(:start_time) }

    it 'validates uniqueness of trace_id' do
      create(:observ_trace, trace_id: 'unique-trace-123')
      should validate_uniqueness_of(:trace_id)
    end
  end

  describe '#create_generation' do
    let(:trace) { create(:observ_trace) }

    it 'creates a generation observation' do
      expect {
        trace.create_generation(name: 'llm_call', model: 'gpt-4o-mini')
      }.to change(trace.observations, :count).by(1)
    end

    it 'sets the correct type' do
      generation = trace.create_generation(name: 'llm_call', model: 'gpt-4o-mini')
      expect(generation).to be_a(Observ::Generation)
      expect(generation.type).to eq('Observ::Generation')
    end

    it 'sets generation attributes' do
      generation = trace.create_generation(
        name: 'test_generation',
        model: 'claude-3-5-sonnet',
        metadata: { phase: 'test' },
        model_parameters: { temperature: 0.5 }
      )

      expect(generation.name).to eq('test_generation')
      expect(generation.model).to eq('claude-3-5-sonnet')
      expect(generation.metadata).to eq({ 'phase' => 'test' })
      expect(generation.model_parameters).to eq({ 'temperature' => 0.5 })
    end
  end

  describe '#create_span' do
    let(:trace) { create(:observ_trace) }

    it 'creates a span observation' do
      expect {
        trace.create_span(name: 'tool:test', input: 'test')
      }.to change(trace.observations, :count).by(1)
    end

    it 'sets the correct type' do
      span = trace.create_span(name: 'tool:test')
      expect(span).to be_a(Observ::Span)
      expect(span.type).to eq('Observ::Span')
    end

    it 'converts hash input to JSON' do
      span = trace.create_span(name: 'tool:test', input: { query: 'search' })
      expect(span.input).to be_a(String)
      expect(JSON.parse(span.input)).to eq({ 'query' => 'search' })
    end
  end

  describe '#create_embedding' do
    let(:trace) { create(:observ_trace) }

    it 'creates an embedding observation' do
      expect {
        trace.create_embedding(name: 'embed', model: 'text-embedding-3-small')
      }.to change(trace.observations, :count).by(1)
    end

    it 'sets the correct type' do
      embedding = trace.create_embedding(name: 'embed', model: 'text-embedding-3-small')
      expect(embedding).to be_a(Observ::Embedding)
      expect(embedding.type).to eq('Observ::Embedding')
    end

    it 'sets embedding attributes' do
      embedding = trace.create_embedding(
        name: 'test_embedding',
        model: 'text-embedding-3-large',
        metadata: { batch_size: 3, dimensions: 3072 }
      )

      expect(embedding.name).to eq('test_embedding')
      expect(embedding.model).to eq('text-embedding-3-large')
      expect(embedding.metadata).to eq({ 'batch_size' => 3, 'dimensions' => 3072 })
    end
  end

  describe '#create_image_generation' do
    let(:trace) { create(:observ_trace) }

    it 'creates an image generation observation' do
      expect {
        trace.create_image_generation(name: 'paint', model: 'dall-e-3')
      }.to change(trace.observations, :count).by(1)
    end

    it 'sets the correct type' do
      image_gen = trace.create_image_generation(name: 'paint', model: 'dall-e-3')
      expect(image_gen).to be_a(Observ::ImageGeneration)
      expect(image_gen.type).to eq('Observ::ImageGeneration')
    end

    it 'sets image generation attributes' do
      image_gen = trace.create_image_generation(
        name: 'test_image',
        model: 'dall-e-3',
        metadata: { size: '1024x1024', output_format: 'url' }
      )

      expect(image_gen.name).to eq('test_image')
      expect(image_gen.model).to eq('dall-e-3')
      expect(image_gen.metadata).to eq({ 'size' => '1024x1024', 'output_format' => 'url' })
    end
  end

  describe '#finalize' do
    let(:trace) { create(:observ_trace) }

    it 'sets end_time' do
      trace.finalize(output: 'response')
      expect(trace.end_time).to be_present
    end

    it 'sets output' do
      trace.finalize(output: 'test response')
      expect(trace.output).to eq('test response')
    end

    it 'merges metadata' do
      trace.metadata = { existing: 'data' }
      trace.finalize(metadata: { new: 'data' })
      expect(trace.metadata).to eq({ 'existing' => 'data', 'new' => 'data' })
    end

    it 'calls update_aggregated_metrics' do
      expect(trace).to receive(:update_aggregated_metrics)
      trace.finalize(output: 'done')
    end

    it 'converts hash output to JSON' do
      trace.finalize(output: { status: 'success' })
      expect(trace.output).to be_a(String)
      expect(JSON.parse(trace.output)).to eq({ 'status' => 'success' })
    end

    it 'evaluates guardrails after completion' do
      expect(Observ::GuardrailService).to receive(:evaluate_trace).with(trace)
      trace.finalize(output: 'done')
    end

    context 'with error span' do
      let!(:error_span) { create(:observ_span, :error, trace: trace) }

      it 'enqueues trace for review automatically' do
        expect {
          trace.finalize(output: 'done')
        }.to change(Observ::ReviewItem, :count).by(1)

        expect(trace.reload.review_item.reason).to eq('error_span')
      end
    end
  end

  describe '#finalize_with_response' do
    let(:trace) { create(:observ_trace) }

    context 'with a string response' do
      it 'finalizes with the string as output' do
        result = trace.finalize_with_response('simple response')
        expect(trace.output).to eq('simple response')
        expect(result).to eq('simple response')
      end
    end

    context 'with a complex response object' do
      it 'extracts content and metadata' do
        response = double(
          content: 'response content',
          model_id: 'gpt-4o-mini',
          input_tokens: 50,
          output_tokens: 50,
          role: :assistant
        )

        result = trace.finalize_with_response(response)
        expect(trace.output).to eq('response content')
        expect(trace.metadata['model_id']).to eq('gpt-4o-mini')
        expect(trace.metadata['total_tokens']).to eq(100)
      end
    end
  end

  describe '#duration_ms' do
    it 'returns nil when not finalized' do
      trace = create(:observ_trace, end_time: nil)
      expect(trace.duration_ms).to be_nil
    end

    it 'calculates duration in milliseconds' do
      start = Time.current
      trace = create(:observ_trace, start_time: start, end_time: start + 2.5.seconds)
      expect(trace.duration_ms).to eq(2500.0)
    end
  end

  describe '#update_aggregated_metrics' do
    let(:trace) { create(:observ_trace) }

    before do
      create(:observ_generation, trace: trace, cost_usd: 0.001,
             usage: { total_tokens: 50 })
      create(:observ_generation, trace: trace, cost_usd: 0.002,
             usage: { total_tokens: 100 })
    end

    it 'updates total_cost from generations' do
      trace.update_aggregated_metrics
      expect(trace.total_cost).to eq(0.003)
    end

    it 'updates total_tokens from generations' do
      trace.update_aggregated_metrics
      expect(trace.total_tokens).to eq(150)
    end
  end

  describe 'scopes' do
    let(:session) { create(:observ_session) }

    describe '#generations' do
      it 'returns only generation observations' do
        trace = create(:observ_trace, observ_session: session)
        gen = create(:observ_generation, trace: trace)
        span = create(:observ_span, trace: trace)

        expect(trace.generations).to include(gen)
        expect(trace.generations).not_to include(span)
      end
    end

    describe '#spans' do
      it 'returns only span observations' do
        trace = create(:observ_trace, observ_session: session)
        gen = create(:observ_generation, trace: trace)
        span = create(:observ_span, trace: trace)

        expect(trace.spans).to include(span)
        expect(trace.spans).not_to include(gen)
      end
    end

    describe '#embeddings' do
      it 'returns only embedding observations' do
        trace = create(:observ_trace, observ_session: session)
        gen = create(:observ_generation, trace: trace)
        span = create(:observ_span, trace: trace)
        embedding = create(:observ_embedding, trace: trace)

        expect(trace.embeddings).to include(embedding)
        expect(trace.embeddings).not_to include(gen)
        expect(trace.embeddings).not_to include(span)
      end
    end

    describe '#image_generations' do
      it 'returns only image generation observations' do
        trace = create(:observ_trace, observ_session: session)
        gen = create(:observ_generation, trace: trace)
        span = create(:observ_span, trace: trace)
        embedding = create(:observ_embedding, trace: trace)
        image_gen = create(:observ_image_generation, trace: trace)

        expect(trace.image_generations).to include(image_gen)
        expect(trace.image_generations).not_to include(gen)
        expect(trace.image_generations).not_to include(span)
        expect(trace.image_generations).not_to include(embedding)
      end
    end
  end

  describe '#update_aggregated_metrics with embeddings' do
    let(:trace) { create(:observ_trace) }

    before do
      create(:observ_generation, trace: trace, cost_usd: 0.001,
             usage: { total_tokens: 50 })
      create(:observ_embedding, trace: trace, cost_usd: 0.0001,
             usage: { input_tokens: 20 })
    end

    it 'includes embedding costs in total_cost' do
      trace.update_aggregated_metrics
      expect(trace.total_cost).to eq(0.0011)
    end

    it 'includes embedding tokens in total_tokens' do
      trace.update_aggregated_metrics
      expect(trace.total_tokens).to eq(70)
    end
  end

  describe '#update_aggregated_metrics with image generations' do
    let(:trace) { create(:observ_trace) }

    before do
      create(:observ_generation, trace: trace, cost_usd: 0.001,
             usage: { total_tokens: 50 })
      create(:observ_image_generation, trace: trace, cost_usd: 0.04)
    end

    it 'includes image generation costs in total_cost' do
      trace.update_aggregated_metrics
      expect(trace.total_cost).to eq(0.041)
    end

    it 'does not include image generations in total_tokens (they have no tokens)' do
      trace.update_aggregated_metrics
      expect(trace.total_tokens).to eq(50)
    end
  end

  describe '#update_aggregated_metrics with all observation types' do
    let(:trace) { create(:observ_trace) }

    before do
      create(:observ_generation, trace: trace, cost_usd: 0.001,
             usage: { total_tokens: 50 })
      create(:observ_embedding, trace: trace, cost_usd: 0.0001,
             usage: { input_tokens: 20 })
      create(:observ_image_generation, trace: trace, cost_usd: 0.04)
    end

    it 'includes all observation types in total_cost' do
      trace.update_aggregated_metrics
      expect(trace.total_cost).to eq(0.0411)
    end

    it 'includes only token-based observations in total_tokens' do
      trace.update_aggregated_metrics
      expect(trace.total_tokens).to eq(70)
    end
  end
end
