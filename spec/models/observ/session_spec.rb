require 'rails_helper'

RSpec.describe Observ::Session, type: :model do
  describe 'associations' do
    it { should have_many(:traces).class_name('Observ::Trace').dependent(:destroy) }
  end

  describe 'validations' do
    it 'validates uniqueness of session_id' do
      create(:observ_session, session_id: 'unique-123')
      should validate_uniqueness_of(:session_id)
    end

    it 'requires session_id and start_time to be present' do
      # Temporarily remove before_validation callbacks to test presence validations
      Observ::Session.skip_callback(:validation, :before, :set_session_id)
      Observ::Session.skip_callback(:validation, :before, :set_start_time)

      session = Observ::Session.new(session_id: nil, start_time: nil)
      expect(session.valid?).to be false
      expect(session.errors[:session_id]).to include("can't be blank")
      expect(session.errors[:start_time]).to include("can't be blank")

      # Re-enable callbacks
      Observ::Session.set_callback(:validation, :before, :set_session_id)
      Observ::Session.set_callback(:validation, :before, :set_start_time)
    end
  end

  describe 'callbacks' do
    describe 'before_validation' do
      it 'sets session_id automatically' do
        session = build(:observ_session, session_id: nil)
        session.valid?
        expect(session.session_id).to be_present
        expect(session.session_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
      end

      it 'sets start_time automatically' do
        session = build(:observ_session, start_time: nil)
        session.valid?
        expect(session.start_time).to be_present
        expect(session.start_time).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe '#create_trace' do
    let(:session) { create(:observ_session) }

    it 'creates a new trace associated with the session' do
      expect {
        session.create_trace(name: 'test_trace', input: 'test input')
      }.to change(session.traces, :count).by(1)
    end

    it 'sets trace attributes correctly' do
      trace = session.create_trace(
        name: 'chat.ask',
        input: 'Hello world',
        metadata: { phase: 'testing' },
        tags: ['test']
      )

      expect(trace.name).to eq('chat.ask')
      expect(trace.input).to eq('Hello world')
      expect(trace.metadata).to eq({ 'phase' => 'testing' })
      expect(trace.tags).to eq(['test'])
      expect(trace.user_id).to eq(session.user_id)
    end

    it 'generates a UUID for trace_id' do
      trace = session.create_trace(name: 'test')
      expect(trace.trace_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it 'converts hash input to JSON' do
      trace = session.create_trace(name: 'test', input: { message: 'hello' })
      expect(trace.input).to be_a(String)
      expect(JSON.parse(trace.input)).to eq({ 'message' => 'hello' })
    end
  end

  describe '#finalize' do
    let(:session) { create(:observ_session) }

    it 'sets end_time' do
      session.finalize
      expect(session.end_time).to be_present
      expect(session.end_time).to be_within(1.second).of(Time.current)
    end

    it 'updates aggregated metrics' do
      expect(session).to receive(:update_aggregated_metrics)
      session.finalize
    end

    it 'evaluates guardrails after completion' do
      expect(Observ::GuardrailService).to receive(:evaluate_session).with(session)
      session.finalize
    end

    context 'with high cost' do
      let(:session) { create(:observ_session, total_cost: 0.60) }

      it 'enqueues session for review automatically' do
        expect {
          session.finalize
        }.to change(Observ::ReviewItem, :count).by(1)

        expect(session.reload.review_item.reason).to eq('high_cost')
      end
    end
  end

  describe '#duration_s' do
    it 'returns nil when session is not finalized' do
      session = create(:observ_session, end_time: nil)
      expect(session.duration_s).to be_nil
    end

    it 'calculates duration in seconds' do
      start = Time.current
      session = create(:observ_session, start_time: start, end_time: start + 45.seconds)
      expect(session.duration_s).to eq(45.0)
    end

    it 'rounds to 1 decimal place' do
      start = Time.current
      session = create(:observ_session, start_time: start, end_time: start + 45.678.seconds)
      expect(session.duration_s).to eq(45.7)
    end
  end

  describe '#average_llm_latency_ms' do
    let(:session) { create(:observ_session) }
    let(:trace) { create(:observ_trace, observ_session: session) }

    it 'returns 0 when there are no generations' do
      expect(session.average_llm_latency_ms).to eq(0)
    end

    it 'calculates average latency across all generations' do
      # Create generations with different durations
      create(:observ_generation, :finalized, trace: trace,
             start_time: Time.current, end_time: Time.current + 1.second)
      create(:observ_generation, :finalized, trace: trace,
             start_time: Time.current, end_time: Time.current + 2.seconds)

      # Average should be 1500ms
      expect(session.average_llm_latency_ms).to be_within(100).of(1500)
    end
  end

  describe '#session_metrics' do
    let(:session) { create(:observ_session, :with_metrics) }

    it 'returns a hash with all session metrics' do
      metrics = session.session_metrics

      expect(metrics).to be_a(Hash)
      expect(metrics[:session_id]).to eq(session.session_id)
      expect(metrics[:total_traces]).to eq(session.total_traces_count)
      expect(metrics[:total_llm_calls]).to eq(session.total_llm_calls_count)
      expect(metrics[:total_tokens]).to eq(session.total_tokens)
      expect(metrics[:total_cost]).to eq(session.total_cost.to_f)
    end
  end

  describe '#update_aggregated_metrics' do
    let(:session) { create(:observ_session) }
    let(:trace1) { create(:observ_trace, :with_metrics, observ_session: session, total_cost: 0.01, total_tokens: 100) }
    let(:trace2) { create(:observ_trace, :with_metrics, observ_session: session, total_cost: 0.02, total_tokens: 200) }

    before do
      trace1
      trace2
    end

    it 'updates total_traces_count' do
      session.update_aggregated_metrics
      expect(session.total_traces_count).to eq(2)
    end

    it 'updates total_tokens' do
      session.update_aggregated_metrics
      expect(session.total_tokens).to eq(300)
    end

    it 'updates total_cost' do
      session.update_aggregated_metrics
      expect(session.total_cost).to eq(0.03)
    end
  end

  describe '#instrument_image_generation' do
    let(:session) { create(:observ_session) }

    it 'returns an ImageGenerationInstrumenter' do
      instrumenter = session.instrument_image_generation
      expect(instrumenter).to be_a(Observ::ImageGenerationInstrumenter)
    end

    it 'passes context to the instrumenter' do
      instrumenter = session.instrument_image_generation(context: { operation: 'product_image' })
      expect(instrumenter.context).to eq({ operation: 'product_image' })
    end

    it 'instruments the instrumenter' do
      instrumenter = session.instrument_image_generation
      expect(instrumenter.instance_variable_get(:@instrumented)).to be true
    end
  end
end
