# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Observ::ModerationInstrumenter do
  let(:session) { create(:observ_session) }
  let(:instrumenter) { described_class.new(session, context: { operation: 'test' }) }

  # Mock RubyLLM.moderate response
  let(:mock_moderation_result) do
    double(
      'ModerationResult',
      flagged?: false,
      categories: {
        'sexual' => false,
        'hate' => false,
        'harassment' => false,
        'self-harm' => false,
        'violence' => false
      },
      category_scores: {
        'sexual' => 0.001,
        'hate' => 0.002,
        'harassment' => 0.003,
        'self-harm' => 0.001,
        'violence' => 0.002
      },
      flagged_categories: [],
      model: 'omni-moderation-latest',
      id: 'modr-123'
    )
  end

  let(:mock_flagged_result) do
    double(
      'FlaggedResult',
      flagged?: true,
      categories: {
        'sexual' => false,
        'hate' => true,
        'harassment' => true,
        'self-harm' => false,
        'violence' => false
      },
      category_scores: {
        'sexual' => 0.001,
        'hate' => 0.95,
        'harassment' => 0.87,
        'self-harm' => 0.001,
        'violence' => 0.002
      },
      flagged_categories: [ 'hate', 'harassment' ],
      model: 'omni-moderation-latest',
      id: 'modr-456'
    )
  end

  before do
    @original_moderate = RubyLLM.method(:moderate) if RubyLLM.respond_to?(:moderate)
    allow(RubyLLM).to receive(:moderate).and_return(mock_moderation_result)

    config_double = double('Config')
    allow(config_double).to receive(:respond_to?).with(:default_moderation_model).and_return(true)
    allow(config_double).to receive(:default_moderation_model).and_return('omni-moderation-latest')
    allow(RubyLLM).to receive(:config).and_return(config_double)
  end

  after do
    RubyLLM.define_singleton_method(:moderate, @original_moderate) if @original_moderate
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
      expect(instrumenter).not_to receive(:wrap_moderate_method)
      instrumenter.instrument!
    end

    it 'logs instrumentation message' do
      expect(Rails.logger).to receive(:info).with(/Instrumented RubyLLM.moderate/)
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

  describe 'moderate call instrumentation' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'creates a trace for each moderate call' do
      expect {
        RubyLLM.moderate("Test content")
      }.to change(session.traces, :count).by(1)
    end

    it 'creates a moderation observation for each call' do
      RubyLLM.moderate("Test content")
      trace = session.traces.last
      expect(trace.moderations.count).to eq(1)
    end

    it 'records the model used' do
      RubyLLM.moderate("Test content")
      moderation = session.traces.last.moderations.first
      expect(moderation.model).to eq('omni-moderation-latest')
    end

    it 'records flagged status in metadata' do
      RubyLLM.moderate("Test content")
      moderation = session.traces.last.moderations.first
      expect(moderation.flagged?).to be false
    end

    it 'records categories in metadata' do
      RubyLLM.moderate("Test content")
      moderation = session.traces.last.moderations.first
      expect(moderation.categories).to include('sexual' => false)
    end

    it 'records category_scores in metadata' do
      RubyLLM.moderate("Test content")
      moderation = session.traces.last.moderations.first
      expect(moderation.category_scores['hate']).to eq(0.002)
    end

    it 'records empty flagged_categories when not flagged' do
      RubyLLM.moderate("Test content")
      moderation = session.traces.last.moderations.first
      expect(moderation.flagged_categories).to eq([])
    end

    it 'returns the original result' do
      result = RubyLLM.moderate("Test content")
      expect(result).to eq(mock_moderation_result)
    end

    it 'includes context in trace metadata' do
      RubyLLM.moderate("Test content")
      trace = session.traces.last
      expect(trace.metadata).to include('operation' => 'test')
    end

    it 'stores truncated text in input' do
      RubyLLM.moderate("Test content for moderation")
      moderation = session.traces.last.moderations.first
      expect(moderation.input).to eq('Test content for moderation')
    end

    it 'has cost_usd of 0.0 (moderation is typically free)' do
      RubyLLM.moderate("Test content")
      moderation = session.traces.last.moderations.first
      expect(moderation.cost_usd).to eq(0.0)
    end
  end

  describe 'flagged content instrumentation' do
    before do
      allow(RubyLLM).to receive(:moderate).and_return(mock_flagged_result)
      instrumenter.instrument!
    end

    after { instrumenter.uninstrument! }

    it 'records flagged as true' do
      RubyLLM.moderate("Hateful content")
      moderation = session.traces.last.moderations.first
      expect(moderation.flagged?).to be true
    end

    it 'records flagged_categories' do
      RubyLLM.moderate("Hateful content")
      moderation = session.traces.last.moderations.first
      expect(moderation.flagged_categories).to eq([ 'hate', 'harassment' ])
    end

    it 'records high category_scores for flagged categories' do
      RubyLLM.moderate("Hateful content")
      moderation = session.traces.last.moderations.first
      expect(moderation.category_scores['hate']).to eq(0.95)
    end

    it 'records flagged in trace metadata' do
      RubyLLM.moderate("Hateful content")
      trace = session.traces.last
      expect(trace.metadata).to include('flagged' => true)
    end

    it 'records flagged_categories_count in trace metadata' do
      RubyLLM.moderate("Hateful content")
      trace = session.traces.last
      expect(trace.metadata).to include('flagged_categories_count' => 2)
    end
  end

  describe 'error handling' do
    before do
      allow(RubyLLM).to receive(:moderate).and_raise(StandardError.new("API Error"))
      instrumenter.instrument!
    end

    after { instrumenter.uninstrument! }

    it 'creates an error span on failure' do
      expect {
        RubyLLM.moderate("Test content") rescue nil
      }.to change(session.traces, :count).by(1)

      trace = session.traces.last
      error_span = trace.spans.find_by(name: 'error')
      expect(error_span).to be_present
      expect(error_span.metadata['error_type']).to eq('StandardError')
    end

    it 'raises the original error' do
      expect {
        RubyLLM.moderate("Test content")
      }.to raise_error(StandardError, "API Error")
    end

    it 'marks moderation as failed' do
      RubyLLM.moderate("Test content") rescue nil
      moderation = session.traces.last.moderations.first
      expect(moderation.status_message).to eq('FAILED')
    end
  end

  describe 'trace aggregation' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'updates trace total_cost (should be 0 for moderation)' do
      RubyLLM.moderate("Test content")
      trace = session.traces.last
      expect(trace.total_cost).to eq(0.0)
    end
  end

  describe 'long text truncation' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'truncates long text in trace input' do
      long_text = "a" * 1000
      RubyLLM.moderate(long_text)
      trace = session.traces.last
      expect(trace.input.length).to be < 1000
    end

    it 'truncates long text in moderation input' do
      long_text = "a" * 2000
      RubyLLM.moderate(long_text)
      moderation = session.traces.last.moderations.first
      expect(moderation.input.length).to be <= 1000
    end
  end

  describe 'nil text handling' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'handles nil text gracefully' do
      allow(RubyLLM).to receive(:moderate).and_return(mock_moderation_result)
      expect {
        RubyLLM.moderate(nil)
      }.not_to raise_error
    end
  end
end
