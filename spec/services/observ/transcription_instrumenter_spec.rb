# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Observ::TranscriptionInstrumenter do
  let(:session) { create(:observ_session) }
  let(:instrumenter) { described_class.new(session, context: { operation: 'test' }) }

  # Mock RubyLLM.transcribe response
  let(:mock_transcription_result) do
    double(
      'TranscriptionResult',
      text: 'Hello, this is a test transcription.',
      model: 'whisper-1',
      duration: 60.0,
      segments: [
        double('Segment', start: 0.0, end: 5.0, text: 'Hello,'),
        double('Segment', start: 5.0, end: 10.0, text: 'this is a test transcription.')
      ]
    )
  end

  let(:mock_diarized_result) do
    segments = [
      double('Segment', start: 0.0, end: 2.0, text: 'Hello.', speaker: 'Speaker 1'),
      double('Segment', start: 2.0, end: 4.0, text: 'Hi there.', speaker: 'Speaker 2')
    ]
    double(
      'DiarizedResult',
      text: 'Speaker 1: Hello. Speaker 2: Hi there.',
      model: 'gpt-4o-transcribe',
      duration: 120.0,
      language: 'en',
      segments: segments
    )
  end

  before do
    @original_transcribe = RubyLLM.method(:transcribe) if RubyLLM.respond_to?(:transcribe)
    allow(RubyLLM).to receive(:transcribe).and_return(mock_transcription_result)

    config_double = double('Config')
    allow(config_double).to receive(:respond_to?).with(:default_transcription_model).and_return(true)
    allow(config_double).to receive(:default_transcription_model).and_return('whisper-1')
    allow(RubyLLM).to receive(:config).and_return(config_double)

    model_info = double('ModelInfo')
    allow(model_info).to receive(:respond_to?).with(:audio_price_per_minute).and_return(true)
    allow(model_info).to receive(:audio_price_per_minute).and_return(0.006)
    models_double = double('Models')
    allow(models_double).to receive(:find).and_return(model_info)
    allow(RubyLLM).to receive(:models).and_return(models_double)
  end

  after do
    RubyLLM.define_singleton_method(:transcribe, @original_transcribe) if @original_transcribe
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
      expect(instrumenter).not_to receive(:wrap_transcribe_method)
      instrumenter.instrument!
    end

    it 'logs instrumentation message' do
      expect(Rails.logger).to receive(:info).with(/Instrumented RubyLLM.transcribe/)
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

  describe 'transcribe call instrumentation' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'creates a trace for each transcribe call' do
      expect {
        RubyLLM.transcribe("meeting.wav")
      }.to change(session.traces, :count).by(1)
    end

    it 'creates a transcription observation for each call' do
      RubyLLM.transcribe("meeting.wav")
      trace = session.traces.last
      expect(trace.transcriptions.count).to eq(1)
    end

    it 'records the model used' do
      RubyLLM.transcribe("meeting.wav")
      transcription = session.traces.last.transcriptions.first
      expect(transcription.model).to eq('whisper-1')
    end

    it 'records audio duration in metadata' do
      RubyLLM.transcribe("meeting.wav")
      transcription = session.traces.last.transcriptions.first
      expect(transcription.audio_duration_s).to eq(60.0)
    end

    it 'records segments count in metadata' do
      RubyLLM.transcribe("meeting.wav")
      transcription = session.traces.last.transcriptions.first
      expect(transcription.segments_count).to eq(2)
    end

    it 'calculates cost based on duration' do
      RubyLLM.transcribe("meeting.wav")
      transcription = session.traces.last.transcriptions.first
      # 60 seconds = 1 minute * $0.006/min = $0.006
      expect(transcription.cost_usd).to eq(0.006)
    end

    it 'returns the original result' do
      result = RubyLLM.transcribe("meeting.wav")
      expect(result).to eq(mock_transcription_result)
    end

    it 'includes context in trace metadata' do
      RubyLLM.transcribe("meeting.wav")
      trace = session.traces.last
      expect(trace.metadata).to include('operation' => 'test')
    end

    it 'stores truncated transcript in input' do
      RubyLLM.transcribe("meeting.wav")
      transcription = session.traces.last.transcriptions.first
      expect(transcription.input).to eq('Hello, this is a test transcription.')
    end
  end

  describe 'diarization instrumentation' do
    before do
      allow(RubyLLM).to receive(:transcribe).and_return(mock_diarized_result)
      instrumenter.instrument!
    end

    after { instrumenter.uninstrument! }

    it 'records has_diarization as true' do
      RubyLLM.transcribe("team-meeting.wav")
      transcription = session.traces.last.transcriptions.first
      expect(transcription.has_diarization?).to be true
    end

    it 'records speakers count' do
      RubyLLM.transcribe("team-meeting.wav")
      transcription = session.traces.last.transcriptions.first
      expect(transcription.speakers_count).to eq(2)
    end

    it 'records language when available' do
      RubyLLM.transcribe("team-meeting.wav")
      transcription = session.traces.last.transcriptions.first
      expect(transcription.language).to eq('en')
    end
  end

  describe 'error handling' do
    before do
      allow(RubyLLM).to receive(:transcribe).and_raise(StandardError.new("API Error"))
      instrumenter.instrument!
    end

    after { instrumenter.uninstrument! }

    it 'creates an error span on failure' do
      expect {
        RubyLLM.transcribe("meeting.wav") rescue nil
      }.to change(session.traces, :count).by(1)

      trace = session.traces.last
      error_span = trace.spans.find_by(name: 'error')
      expect(error_span).to be_present
      expect(error_span.metadata['error_type']).to eq('StandardError')
    end

    it 'raises the original error' do
      expect {
        RubyLLM.transcribe("meeting.wav")
      }.to raise_error(StandardError, "API Error")
    end

    it 'marks transcription as failed' do
      RubyLLM.transcribe("meeting.wav") rescue nil
      transcription = session.traces.last.transcriptions.first
      expect(transcription.status_message).to eq('FAILED')
    end
  end

  describe 'cost calculation' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'returns 0 when model info not found' do
      allow(RubyLLM.models).to receive(:find).and_return(nil)
      RubyLLM.transcribe("meeting.wav")
      transcription = session.traces.last.transcriptions.first
      expect(transcription.cost_usd).to eq(0.0)
    end

    it 'falls back to token estimation when audio_price_per_minute not available' do
      model_info = double('ModelInfo')
      allow(model_info).to receive(:respond_to?).with(:audio_price_per_minute).and_return(false)
      allow(model_info).to receive(:respond_to?).with(:input_price_per_million).and_return(true)
      allow(model_info).to receive(:input_price_per_million).and_return(0.15)
      allow(RubyLLM.models).to receive(:find).and_return(model_info)

      RubyLLM.transcribe("meeting.wav")
      transcription = session.traces.last.transcriptions.first
      # 60s = 1 minute * 150 tokens/min * $0.15/1M = 0.0000225
      expect(transcription.cost_usd).to be > 0
    end

    it 'returns 0 when no pricing available' do
      model_info = double('ModelInfo')
      allow(model_info).to receive(:respond_to?).with(:audio_price_per_minute).and_return(false)
      allow(model_info).to receive(:respond_to?).with(:input_price_per_million).and_return(false)
      allow(RubyLLM.models).to receive(:find).and_return(model_info)

      RubyLLM.transcribe("meeting.wav")
      transcription = session.traces.last.transcriptions.first
      expect(transcription.cost_usd).to eq(0.0)
    end
  end

  describe 'trace aggregation' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'updates trace total_cost' do
      RubyLLM.transcribe("meeting.wav")
      trace = session.traces.last
      expect(trace.total_cost).to eq(0.006)
    end
  end

  describe 'with language option' do
    before { instrumenter.instrument! }
    after { instrumenter.uninstrument! }

    it 'records specified language in trace metadata' do
      RubyLLM.transcribe("meeting.wav", language: "es")
      trace = session.traces.last
      expect(trace.metadata).to include('language' => 'es')
    end
  end
end
