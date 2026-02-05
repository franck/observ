# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Observ::Moderation, type: :model do
  describe '#finalize' do
    let(:moderation) { create(:observ_moderation) }

    it 'sets all moderation-specific fields' do
      moderation.finalize(
        output: { model: 'omni-moderation-latest', flagged: false },
        cost_usd: 0.0
      )

      expect(JSON.parse(moderation.output)).to include('model' => 'omni-moderation-latest')
      expect(moderation.cost_usd).to eq(0.0)
      expect(moderation.end_time).to be_present
    end

    it 'merges usage with existing usage' do
      moderation.usage = { existing: 'data' }
      moderation.finalize(
        output: 'test',
        usage: { api_calls: 1 }
      )
      expect(moderation.usage).to include('existing' => 'data', 'api_calls' => 1)
    end

    it 'converts hash output to JSON' do
      moderation.finalize(output: { result: 'success' })
      expect(moderation.output).to be_a(String)
      expect(JSON.parse(moderation.output)).to eq({ 'result' => 'success' })
    end

    it 'sets status_message when provided' do
      moderation.finalize(output: 'test', status_message: 'COMPLETED')
      expect(moderation.status_message).to eq('COMPLETED')
    end
  end

  describe '#flagged?' do
    it 'returns true when flagged is true' do
      moderation = create(:observ_moderation, metadata: { flagged: true })
      expect(moderation.flagged?).to be true
    end

    it 'returns false when flagged is false' do
      moderation = create(:observ_moderation, metadata: { flagged: false })
      expect(moderation.flagged?).to be false
    end

    it 'returns false when flagged not set' do
      moderation = create(:observ_moderation, metadata: {})
      expect(moderation.flagged?).to be false
    end
  end

  describe '#categories' do
    it 'returns categories from metadata' do
      categories = { 'hate' => true, 'violence' => false }
      moderation = create(:observ_moderation, metadata: { categories: categories })
      expect(moderation.categories).to eq(categories)
    end

    it 'returns empty hash when categories not set' do
      moderation = create(:observ_moderation, metadata: {})
      expect(moderation.categories).to eq({})
    end
  end

  describe '#category_scores' do
    it 'returns category_scores from metadata' do
      scores = { 'hate' => 0.95, 'violence' => 0.12 }
      moderation = create(:observ_moderation, metadata: { category_scores: scores })
      expect(moderation.category_scores).to eq(scores)
    end

    it 'returns empty hash when category_scores not set' do
      moderation = create(:observ_moderation, metadata: {})
      expect(moderation.category_scores).to eq({})
    end
  end

  describe '#flagged_categories' do
    it 'returns flagged_categories from metadata' do
      flagged = [ 'hate', 'harassment' ]
      moderation = create(:observ_moderation, metadata: { flagged_categories: flagged })
      expect(moderation.flagged_categories).to eq(flagged)
    end

    it 'returns empty array when flagged_categories not set' do
      moderation = create(:observ_moderation, metadata: {})
      expect(moderation.flagged_categories).to eq([])
    end
  end

  describe '#highest_score_category' do
    it 'returns the category with highest score' do
      scores = { 'hate' => 0.95, 'violence' => 0.12, 'harassment' => 0.87 }
      moderation = create(:observ_moderation, metadata: { category_scores: scores })
      expect(moderation.highest_score_category).to eq('hate')
    end

    it 'returns nil when category_scores is empty' do
      moderation = create(:observ_moderation, metadata: { category_scores: {} })
      expect(moderation.highest_score_category).to be_nil
    end

    it 'returns nil when category_scores not set' do
      moderation = create(:observ_moderation, metadata: {})
      expect(moderation.highest_score_category).to be_nil
    end
  end

  describe 'STI type' do
    it 'has the correct type' do
      moderation = create(:observ_moderation)
      expect(moderation.type).to eq('Observ::Moderation')
    end

    it 'is a subclass of Observation' do
      expect(Observ::Moderation.superclass).to eq(Observ::Observation)
    end
  end

  describe 'finalized trait' do
    let(:moderation) { create(:observ_moderation, :finalized) }

    it 'has end_time set' do
      expect(moderation.end_time).to be_present
    end

    it 'has output set' do
      expect(moderation.output).to be_present
    end
  end

  describe 'flagged trait' do
    let(:moderation) { create(:observ_moderation, :flagged) }

    it 'has flagged set to true' do
      expect(moderation.flagged?).to be true
    end

    it 'has flagged_categories populated' do
      expect(moderation.flagged_categories).to include('hate', 'harassment')
    end

    it 'has high scores for flagged categories' do
      expect(moderation.category_scores['hate']).to be > 0.8
    end
  end

  describe 'high_violence_score trait' do
    let(:moderation) { create(:observ_moderation, :high_violence_score) }

    it 'has violence in flagged_categories' do
      expect(moderation.flagged_categories).to include('violence')
    end

    it 'returns violence as highest score category' do
      expect(moderation.highest_score_category).to eq('violence')
    end
  end
end
