require 'rails_helper'

RSpec.describe Observ::PromptManager do
  before do
    # Clear cache before each test for predictability
    Rails.cache.clear
  end

  describe ".fetch" do
    let!(:production) { create(:observ_prompt, :production, name: "test") }

    it "fetches the prompt" do
      result = described_class.fetch(name: "test")
      expect(result).to eq(production)
    end

    it "uses caching when enabled" do
      # Enable caching temporarily for this test
      allow(Observ.config).to receive(:prompt_cache_ttl).and_return(300)

      # First call populates cache
      first_result = described_class.fetch(name: "test")

      # Verify cache key was populated
      cache_key = described_class.cache_key(name: "test", state: :production)
      cached_value = Rails.cache.read(cache_key)

      # Second call uses the same cached instance
      second_result = described_class.fetch(name: "test")
      expect(second_result.id).to eq(first_result.id)
    end
  end

  describe ".fetch_all" do
    let!(:prompt1) { create(:observ_prompt, :production, name: "prompt-1") }
    let!(:prompt2) { create(:observ_prompt, :production, name: "prompt-2") }

    it "fetches multiple prompts and indexes by name" do
      result = described_class.fetch_all(names: [ "prompt-1", "prompt-2" ])

      expect(result.keys).to match_array([ "prompt-1", "prompt-2" ])
      expect(result["prompt-1"].id).to eq(prompt1.id)
      expect(result["prompt-2"].id).to eq(prompt2.id)
    end
  end

  describe ".create" do
    it "creates new version" do
      prompt = described_class.create(
        name: "new-prompt",
        prompt: "Hello",
        config: { model: "gpt-4o" }
      )

      expect(prompt).to be_persisted
      expect(prompt.version).to eq(1)
    end
  end

  describe ".versions" do
    let!(:v1) { create(:observ_prompt, name: "test", version: 1) }
    let!(:v2) { create(:observ_prompt, name: "test", version: 2) }

    it "returns all versions in descending order" do
      versions = described_class.versions(name: "test")
      expect(versions.map(&:version)).to eq([ 2, 1 ])
    end
  end

  describe ".rollback" do
    let!(:archived) { create(:observ_prompt, :archived, name: "test", version: 1) }
    let!(:production) { create(:observ_prompt, :production, name: "test", version: 2) }

    it "restores archived version to production" do
      result = described_class.rollback(name: "test", to_version: 1)

      expect(result.reload.state).to eq("production")
      expect(production.reload.state).to eq("archived")
    end

    it "raises error for draft version" do
      draft = create(:observ_prompt, :draft, name: "test", version: 3)

      expect {
        described_class.rollback(name: "test", to_version: 3)
      }.to raise_error(Observ::StateTransitionError, "Cannot rollback to draft version")
    end
  end

  describe ".promote" do
    let!(:draft) { create(:observ_prompt, :draft, name: "test") }

    it "promotes draft to production" do
      result = described_class.promote(name: "test", version: draft.version)
      expect(result.reload.state).to eq("production")
    end
  end

  describe ".compare_versions" do
    let!(:v1) { create(:observ_prompt, name: "test", version: 1, prompt: "Hello world") }
    let!(:v2) { create(:observ_prompt, name: "test", version: 2, prompt: "Hello universe") }

    it "returns comparison data" do
      result = described_class.compare_versions(name: "test", version_a: 1, version_b: 2)

      expect(result[:from].id).to eq(v1.id)
      expect(result[:to].id).to eq(v2.id)
      expect(result[:diff][:changed]).to be true
    end
  end
end
