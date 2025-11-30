# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Observ::Transcription, type: :model do
  describe '#finalize' do
    let(:transcription) { create(:observ_transcription) }

    it 'sets all transcription-specific fields' do
      transcription.finalize(
        output: { text: 'Hello world', model: 'whisper-1' },
        cost_usd: 0.006
      )

      expect(JSON.parse(transcription.output)).to include('text' => 'Hello world')
      expect(transcription.cost_usd).to eq(0.006)
      expect(transcription.end_time).to be_present
    end

    it 'merges usage with existing usage' do
      transcription.usage = { existing: 'data' }
      transcription.finalize(
        output: 'test',
        usage: { audio_seconds: 60 }
      )
      expect(transcription.usage).to include('existing' => 'data', 'audio_seconds' => 60)
    end

    it 'converts hash output to JSON' do
      transcription.finalize(output: { result: 'success' })
      expect(transcription.output).to be_a(String)
      expect(JSON.parse(transcription.output)).to eq({ 'result' => 'success' })
    end

    it 'sets status_message when provided' do
      transcription.finalize(output: 'test', status_message: 'COMPLETED')
      expect(transcription.status_message).to eq('COMPLETED')
    end
  end

  describe '#audio_duration_s' do
    it 'returns audio_duration_s from metadata' do
      transcription = create(:observ_transcription, metadata: { audio_duration_s: 120.5 })
      expect(transcription.audio_duration_s).to eq(120.5)
    end

    it 'returns nil when audio_duration_s not set' do
      transcription = create(:observ_transcription, metadata: {})
      expect(transcription.audio_duration_s).to be_nil
    end
  end

  describe '#language' do
    it 'returns language from metadata' do
      transcription = create(:observ_transcription, metadata: { language: 'es' })
      expect(transcription.language).to eq('es')
    end

    it 'returns nil when language not set' do
      transcription = create(:observ_transcription, metadata: {})
      expect(transcription.language).to be_nil
    end
  end

  describe '#segments_count' do
    it 'returns segments_count from metadata' do
      transcription = create(:observ_transcription, metadata: { segments_count: 25 })
      expect(transcription.segments_count).to eq(25)
    end

    it 'returns 0 when segments_count not set' do
      transcription = create(:observ_transcription, metadata: {})
      expect(transcription.segments_count).to eq(0)
    end
  end

  describe '#speakers_count' do
    it 'returns speakers_count from metadata' do
      transcription = create(:observ_transcription, metadata: { speakers_count: 3 })
      expect(transcription.speakers_count).to eq(3)
    end

    it 'returns nil when speakers_count not set' do
      transcription = create(:observ_transcription, metadata: {})
      expect(transcription.speakers_count).to be_nil
    end
  end

  describe '#has_diarization?' do
    it 'returns true when has_diarization is true' do
      transcription = create(:observ_transcription, metadata: { has_diarization: true })
      expect(transcription.has_diarization?).to be true
    end

    it 'returns false when has_diarization is false' do
      transcription = create(:observ_transcription, metadata: { has_diarization: false })
      expect(transcription.has_diarization?).to be false
    end

    it 'returns false when has_diarization not set' do
      transcription = create(:observ_transcription, metadata: {})
      expect(transcription.has_diarization?).to be false
    end
  end

  describe 'STI type' do
    it 'has the correct type' do
      transcription = create(:observ_transcription)
      expect(transcription.type).to eq('Observ::Transcription')
    end

    it 'is a subclass of Observation' do
      expect(Observ::Transcription.superclass).to eq(Observ::Observation)
    end
  end

  describe 'finalized trait' do
    let(:transcription) { create(:observ_transcription, :finalized) }

    it 'has end_time set' do
      expect(transcription.end_time).to be_present
    end

    it 'has output set' do
      expect(transcription.output).to be_present
    end
  end

  describe 'with_diarization trait' do
    let(:transcription) { create(:observ_transcription, :with_diarization) }

    it 'has diarization metadata' do
      expect(transcription.has_diarization?).to be true
      expect(transcription.speakers_count).to eq(3)
    end
  end
end
