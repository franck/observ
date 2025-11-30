require 'rails_helper'

RSpec.describe Observ::ImageGenerationInstrumenter do
  let(:session) { create(:observ_session) }
  let(:instrumenter) { described_class.new(session, context: { operation: 'test' }) }

  # Mock RubyLLM.paint response
  let(:mock_image_result) do
    double(
      'ImageResult',
      url: 'https://example.com/image.png',
      data: nil,
      base64?: false,
      mime_type: 'image/png',
      revised_prompt: 'An enhanced version of the prompt',
      model_id: 'dall-e-3'
    )
  end

  let(:mock_base64_image_result) do
    double(
      'Base64ImageResult',
      url: nil,
      data: 'base64encodeddata...',
      base64?: true,
      mime_type: 'image/png',
      revised_prompt: nil,
      model_id: 'imagen-3.0-generate-002'
    )
  end

  before do
    @original_paint = RubyLLM.method(:paint) if RubyLLM.respond_to?(:paint)
    allow(RubyLLM).to receive(:paint).and_return(mock_image_result)

    config_double = double('Config')
    allow(config_double).to receive(:respond_to?).with(:default_image_model).and_return(true)
    allow(config_double).to receive(:default_image_model).and_return('dall-e-3')
    allow(RubyLLM).to receive(:config).and_return(config_double)

    model_info = double('ModelInfo')
    allow(model_info).to receive(:respond_to?).with(:image_price).and_return(true)
    allow(model_info).to receive(:image_price).and_return(0.04)
    models_double = double('Models')
    allow(models_double).to receive(:find).and_return(model_info)
    allow(RubyLLM).to receive(:models).and_return(models_double)
  end

  after do
    RubyLLM.define_singleton_method(:paint, @original_paint) if @original_paint
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
      expect(instrumenter).not_to receive(:wrap_paint_method)
      instrumenter.instrument!
    end

    it 'logs instrumentation message' do
      expect(Rails.logger).to receive(:info).with(/Instrumented RubyLLM.paint/)
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

  describe 'paint call instrumentation' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'creates a trace for each paint call' do
      expect {
        RubyLLM.paint("A sunset over mountains")
      }.to change(session.traces, :count).by(1)
    end

    it 'creates an image_generation observation for each call' do
      RubyLLM.paint("A sunset over mountains")
      trace = session.traces.last
      expect(trace.image_generations.count).to eq(1)
    end

    it 'records the model used' do
      RubyLLM.paint("A sunset over mountains")
      image_gen = session.traces.last.image_generations.first
      expect(image_gen.model).to eq('dall-e-3')
    end

    it 'records revised_prompt in metadata' do
      RubyLLM.paint("A sunset over mountains")
      image_gen = session.traces.last.image_generations.first
      expect(image_gen.revised_prompt).to eq('An enhanced version of the prompt')
    end

    it 'records output_format as url' do
      RubyLLM.paint("A sunset over mountains")
      image_gen = session.traces.last.image_generations.first
      expect(image_gen.output_format).to eq('url')
    end

    it 'records mime_type' do
      RubyLLM.paint("A sunset over mountains")
      image_gen = session.traces.last.image_generations.first
      expect(image_gen.mime_type).to eq('image/png')
    end

    it 'calculates cost' do
      RubyLLM.paint("A sunset over mountains")
      image_gen = session.traces.last.image_generations.first
      expect(image_gen.cost_usd).to eq(0.04)
    end

    it 'returns the original result' do
      result = RubyLLM.paint("A sunset over mountains")
      expect(result).to eq(mock_image_result)
    end

    it 'includes context in trace metadata' do
      RubyLLM.paint("A sunset over mountains")
      trace = session.traces.last
      expect(trace.metadata).to include('operation' => 'test')
    end
  end

  describe 'base64 image instrumentation' do
    before do
      allow(RubyLLM).to receive(:paint).and_return(mock_base64_image_result)
      instrumenter.instrument!
    end

    after { instrumenter.uninstrument! }

    it 'records output_format as base64' do
      RubyLLM.paint("A sunset over mountains")
      image_gen = session.traces.last.image_generations.first
      expect(image_gen.output_format).to eq('base64')
    end
  end

  describe 'error handling' do
    before do
      allow(RubyLLM).to receive(:paint).and_raise(StandardError.new("API Error"))
      instrumenter.instrument!
    end

    after { instrumenter.uninstrument! }

    it 'creates an error span on failure' do
      expect {
        RubyLLM.paint("A sunset") rescue nil
      }.to change(session.traces, :count).by(1)

      trace = session.traces.last
      error_span = trace.spans.find_by(name: 'error')
      expect(error_span).to be_present
      expect(error_span.metadata['error_type']).to eq('StandardError')
    end

    it 'raises the original error' do
      expect {
        RubyLLM.paint("A sunset")
      }.to raise_error(StandardError, "API Error")
    end

    it 'marks image_generation as failed' do
      RubyLLM.paint("A sunset") rescue nil
      image_gen = session.traces.last.image_generations.first
      expect(image_gen.status_message).to eq('FAILED')
    end
  end

  describe 'trace aggregation' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'updates trace total_cost' do
      RubyLLM.paint("A sunset over mountains")
      trace = session.traces.last
      expect(trace.total_cost).to eq(0.04)
    end
  end

  describe 'cost calculation' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'returns 0 when model info not found' do
      allow(RubyLLM.models).to receive(:find).and_return(nil)
      RubyLLM.paint("A sunset")
      image_gen = session.traces.last.image_generations.first
      expect(image_gen.cost_usd).to eq(0.0)
    end

    it 'falls back to output_price_per_million when image_price not available' do
      model_info = double('ModelInfo')
      allow(model_info).to receive(:respond_to?).with(:image_price).and_return(false)
      allow(model_info).to receive(:respond_to?).with(:output_price_per_million).and_return(true)
      allow(model_info).to receive(:output_price_per_million).and_return(40.0)
      allow(RubyLLM.models).to receive(:find).and_return(model_info)

      RubyLLM.paint("A sunset")
      image_gen = session.traces.last.image_generations.first
      expect(image_gen.cost_usd).to eq(0.04)
    end

    it 'returns 0 when no pricing available' do
      model_info = double('ModelInfo')
      allow(model_info).to receive(:respond_to?).with(:image_price).and_return(false)
      allow(model_info).to receive(:respond_to?).with(:output_price_per_million).and_return(false)
      allow(RubyLLM.models).to receive(:find).and_return(model_info)

      RubyLLM.paint("A sunset")
      image_gen = session.traces.last.image_generations.first
      expect(image_gen.cost_usd).to eq(0.0)
    end
  end
end
