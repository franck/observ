require 'rails_helper'

RSpec.describe Observ::PromptManager, '.caching' do
  let(:prompt_name) { 'test-prompt' }
  let!(:prompt) do
    create(:observ_prompt, :production,
      name: prompt_name,
      prompt: 'Test prompt content'
    )
  end

  before do
    # Use memory store for caching tests instead of null_store
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear

    allow(Observ.config).to receive(:prompt_cache_ttl).and_return(300)
    allow(Observ.config).to receive(:prompt_cache_monitoring_enabled).and_return(true)
  end

  after do
    # Restore original cache
    Rails.cache = @original_cache
  end

  describe '.cache_key' do
    it 'generates key for version-based fetch' do
      key = described_class.cache_key(name: prompt_name, version: 1)
      expect(key).to eq("observ:prompt:#{prompt_name}:version:1")
    end

    it 'generates key for state-based fetch' do
      key = described_class.cache_key(name: prompt_name, state: :production)
      expect(key).to eq("observ:prompt:#{prompt_name}:state:production")
    end

    it 'generates default production key' do
      key = described_class.cache_key(name: prompt_name)
      expect(key).to eq("observ:prompt:#{prompt_name}:production")
    end
  end

  describe '.fetch with caching' do
    context 'when cache is empty' do
      it 'fetches from database and caches result' do
        expect {
          result = described_class.fetch(name: prompt_name, state: :production)
          expect(result).to eq(prompt)
        }.to change { Rails.cache.exist?(described_class.cache_key(name: prompt_name, state: :production)) }
          .from(false).to(true)
      end

      it 'tracks cache miss' do
        described_class.fetch(name: prompt_name, state: :production)

        stats = described_class.cache_stats(prompt_name)
        expect(stats[:misses]).to eq(1)
        expect(stats[:hits]).to eq(0)
      end
    end

    context 'when cache is populated' do
      before do
        # Pre-populate cache
        described_class.fetch(name: prompt_name, state: :production)
      end

      it 'fetches from cache without hitting database' do
        expect(Observ::Prompt).not_to receive(:where)

        result = described_class.fetch(name: prompt_name, state: :production)
        expect(result).to eq(prompt)
      end

      it 'tracks cache hit' do
        # First fetch populates cache (1 miss)
        # Second fetch hits cache (1 hit)
        described_class.fetch(name: prompt_name, state: :production)

        stats = described_class.cache_stats(prompt_name)
        expect(stats[:hits]).to eq(1)
        expect(stats[:misses]).to eq(1)
      end
    end

    context 'when caching is disabled' do
      before do
        allow(Observ.config).to receive(:prompt_cache_ttl).and_return(0)
      end

      it 'fetches from database every time' do
        expect(Observ::Prompt).to receive(:where).twice.and_call_original

        described_class.fetch(name: prompt_name, state: :production)
        described_class.fetch(name: prompt_name, state: :production)
      end
    end

    context 'when cache fetch raises error' do
      before do
        allow(Rails.cache).to receive(:fetch).and_raise(StandardError, "Cache error")
      end

      it 'falls back to database' do
        expect(Rails.logger).to receive(:error).with(/Cache fetch failed/)

        result = described_class.fetch(name: prompt_name, state: :production)
        expect(result).to eq(prompt)
      end
    end
  end

  describe '.invalidate_cache' do
    it 'clears all state-based caches for a prompt' do
      # Populate cache first
      described_class.fetch(name: prompt_name, state: :production)

      expect {
        described_class.invalidate_cache(name: prompt_name)
      }.to change {
        Rails.cache.exist?(described_class.cache_key(name: prompt_name, state: :production))
      }.from(true).to(false)
    end

    it 'clears specific version cache' do
      version_key = described_class.cache_key(name: prompt_name, version: 1)
      Rails.cache.write(version_key, prompt)

      expect {
        described_class.invalidate_cache(name: prompt_name, version: 1)
      }.to change { Rails.cache.exist?(version_key) }.from(true).to(false)
    end

    it 'logs cache invalidation' do
      expect(Rails.logger).to receive(:info).with(/Cache invalidated/)
      described_class.invalidate_cache(name: prompt_name)
    end
  end

  describe '.warm_cache' do
    let!(:prompt2) { create(:observ_prompt, :production, name: 'test-prompt-2') }

    it 'warms cache for all production prompts' do
      results = described_class.warm_cache

      expect(results[:success]).to include(prompt_name, 'test-prompt-2')
      expect(results[:failed]).to be_empty

      # Verify cache is populated
      expect(Rails.cache.exist?(described_class.cache_key(name: prompt_name, state: :production))).to be true
      expect(Rails.cache.exist?(described_class.cache_key(name: 'test-prompt-2', state: :production))).to be true
    end

    it 'warms cache for specific prompts' do
      results = described_class.warm_cache([prompt_name])

      expect(results[:success]).to eq([prompt_name])
      expect(results[:failed]).to be_empty
    end

    it 'handles errors gracefully' do
      allow(described_class).to receive(:fetch).with(name: prompt_name, state: :production)
        .and_raise(StandardError, "DB error")

      results = described_class.warm_cache([prompt_name])

      expect(results[:success]).to be_empty
      expect(results[:failed].first[:name]).to eq(prompt_name)
      expect(results[:failed].first[:error]).to eq("DB error")
    end
  end

  describe '.cache_stats' do
    it 'returns statistics for a prompt' do
      # Generate some cache activity
      3.times { described_class.fetch(name: prompt_name, state: :production) }

      stats = described_class.cache_stats(prompt_name)

      expect(stats[:name]).to eq(prompt_name)
      expect(stats[:hits]).to eq(2)  # First is miss, next 2 are hits
      expect(stats[:misses]).to eq(1)
      expect(stats[:total]).to eq(3)
      expect(stats[:hit_rate]).to eq(66.67)
    end

    it 'returns zeros for prompts with no activity' do
      stats = described_class.cache_stats('non-existent-prompt')

      expect(stats[:hits]).to eq(0)
      expect(stats[:misses]).to eq(0)
      expect(stats[:total]).to eq(0)
      expect(stats[:hit_rate]).to eq(0)
    end
  end

  describe '.clear_stats' do
    it 'clears all cache statistics' do
      # Generate some cache activity (miss + hit)
      described_class.fetch(name: prompt_name, state: :production)
      described_class.fetch(name: prompt_name, state: :production)

      # Verify we have stats
      stats_before = described_class.cache_stats(prompt_name)
      expect(stats_before[:total]).to be > 0

      # Clear stats
      described_class.clear_stats

      # Verify stats are cleared
      stats_after = described_class.cache_stats(prompt_name)
      expect(stats_after[:hits]).to eq(0)
      expect(stats_after[:misses]).to eq(0)
    end
  end

  describe 'cache invalidation on model changes' do
    it 'invalidates cache when prompt is updated' do
      # Create a draft prompt so we can update it
      draft_prompt = create(:observ_prompt, :draft, name: 'updatable-prompt', version: 1)

      # Populate cache
      described_class.fetch(name: 'updatable-prompt', state: :draft)

      # Verify cache exists
      cache_key = described_class.cache_key(name: 'updatable-prompt', state: :draft)
      expect(Rails.cache.exist?(cache_key)).to be true

      # Update should trigger invalidation
      expect(Observ::PromptManager).to receive(:invalidate_cache).with(name: 'updatable-prompt').and_call_original
      draft_prompt.update(prompt: 'Updated content')

      # Cache should be cleared
      expect(Rails.cache.exist?(cache_key)).to be false
    end

    it 'invalidates cache when state changes' do
      draft = create(:observ_prompt, :draft, name: 'draft-prompt')
      described_class.fetch(name: 'draft-prompt', state: :draft)

      cache_key = described_class.cache_key(name: 'draft-prompt', state: :draft)
      expect(Rails.cache.exist?(cache_key)).to be true

      expect(Observ::PromptManager).to receive(:invalidate_cache).with(name: 'draft-prompt').at_least(:once).and_call_original
      draft.promote!

      expect(Rails.cache.exist?(cache_key)).to be false
    end

    it 'invalidates cache when prompt is destroyed' do
      described_class.fetch(name: prompt_name, state: :production)

      cache_key = described_class.cache_key(name: prompt_name, state: :production)
      expect(Rails.cache.exist?(cache_key)).to be true

      expect(Observ::PromptManager).to receive(:invalidate_cache).with(name: prompt_name).and_call_original
      prompt.destroy

      expect(Rails.cache.exist?(cache_key)).to be false
    end
  end
end
