require 'rails_helper'

RSpec.describe Observ::Observation, type: :model do
  describe 'associations' do
    it { should belong_to(:trace).class_name('Observ::Trace') }
  end

  describe 'validations' do
    it { should validate_presence_of(:observation_id) }
    it { should validate_presence_of(:start_time) }
    it { should validate_presence_of(:type) }

    it 'validates uniqueness of observation_id' do
      create(:observ_generation, observation_id: 'unique-obs-123')
      should validate_uniqueness_of(:observation_id)
    end

    it 'validates type inclusion' do
      should validate_inclusion_of(:type).in_array(%w[Observ::Generation Observ::Span])
    end
  end

  describe '#finalize' do
    let(:observation) { create(:observ_generation) }

    it 'sets end_time' do
      observation.finalize(output: 'test output')
      expect(observation.end_time).to be_present
      expect(observation.end_time).to be_within(1.second).of(Time.current)
    end

    it 'sets status_message when provided' do
      observation.finalize(output: 'test output', status_message: 'completed')
      expect(observation.status_message).to eq('completed')
    end
  end

  describe '#duration_ms' do
    it 'returns nil when not finalized' do
      observation = create(:observ_generation, end_time: nil)
      expect(observation.duration_ms).to be_nil
    end

    it 'calculates duration in milliseconds' do
      start = Time.current
      observation = create(:observ_generation, start_time: start, end_time: start + 1.5.seconds)
      expect(observation.duration_ms).to eq(1500.0)
    end

    it 'rounds to 2 decimal places' do
      start = Time.current
      observation = create(:observ_generation, start_time: start, end_time: start + 1.2345.seconds)
      expect(observation.duration_ms).to eq(1234.5)
    end
  end
end
