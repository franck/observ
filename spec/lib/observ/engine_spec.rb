# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Observ::Engine do
  describe "engine initialization" do
    it "loads the engine" do
      expect(Observ::Engine).to be_a(Class)
      expect(Observ::Engine.superclass).to eq(Rails::Engine)
    end

    it "isolates namespace" do
      expect(Observ::Engine.isolated?).to be true
    end
  end

  describe "PromptManager" do
    context "when modules are loaded" do
      it "can generate cache keys" do
        key = Observ::PromptManager.cache_key(name: "test", state: :production)
        expect(key).to be_a(String)
        expect(key).to include("test")
        expect(key).to include("production")
      end

      it "can fetch prompts with fallback" do
        result = Observ::PromptManager.fetch(
          name: "nonexistent",
          state: :production,
          fallback: "fallback value"
        )
        expect(result).to eq("fallback value")
      end

      it "can create new prompt versions" do
        prompt = Observ::PromptManager.create(
          name: "engine-test-prompt",
          prompt: "Test prompt content",
          config: { model: "gpt-4" }
        )
        expect(prompt).to be_persisted
        expect(prompt.name).to eq("engine-test-prompt")
        expect(prompt.version).to eq(1)
      end

      it "can retrieve cache statistics" do
        stats = Observ::PromptManager.cache_stats("test-prompt")
        expect(stats).to be_a(Hash)
        expect(stats).to have_key(:name)
        expect(stats).to have_key(:hits)
        expect(stats).to have_key(:misses)
        expect(stats).to have_key(:hit_rate)
      end

      it "can compare versions" do
        v1 = create(:observ_prompt, name: "compare-test", version: 1, prompt: "Version 1")
        v2 = create(:observ_prompt, name: "compare-test", version: 2, prompt: "Version 2")

        result = Observ::PromptManager.compare_versions(
          name: "compare-test",
          version_a: 1,
          version_b: 2
        )

        expect(result).to have_key(:from)
        expect(result).to have_key(:to)
        expect(result).to have_key(:diff)
        expect(result[:from].id).to eq(v1.id)
        expect(result[:to].id).to eq(v2.id)
      end

      it "can invalidate cache" do
        create(:observ_prompt, :production, name: "cache-test")

        # Warm the cache
        Observ::PromptManager.fetch(name: "cache-test", state: :production)

        # Invalidate
        result = Observ::PromptManager.invalidate_cache(name: "cache-test")
        expect(result).to be true
      end

      it "can warm cache" do
        create(:observ_prompt, :production, name: "warm-test")

        result = Observ::PromptManager.warm_cache([ "warm-test" ])
        expect(result).to have_key(:success)
        expect(result).to have_key(:failed)
        expect(result[:success]).to include("warm-test")
      end

      it "can list versions" do
        create(:observ_prompt, name: "versions-test", version: 1)
        create(:observ_prompt, name: "versions-test", version: 2)

        versions = Observ::PromptManager.versions(name: "versions-test")
        expect(versions.count).to eq(2)
        expect(versions.map(&:version)).to eq([ 2, 1 ])
      end

      it "can promote drafts" do
        draft = create(:observ_prompt, :draft, name: "promote-test")

        result = Observ::PromptManager.promote(name: "promote-test", version: draft.version)
        expect(result.reload.state).to eq("production")
      end

      it "can demote production" do
        production = create(:observ_prompt, :production, name: "demote-test")

        result = Observ::PromptManager.demote(name: "demote-test", version: production.version)
        expect(result.reload.state).to eq("archived")
      end

      it "can restore archived" do
        archived = create(:observ_prompt, :archived, name: "restore-test")

        result = Observ::PromptManager.restore(name: "restore-test", version: archived.version)
        expect(result.reload.state).to eq("production")
      end

      it "can rollback to archived version" do
        archived = create(:observ_prompt, :archived, name: "rollback-test", version: 1)
        production = create(:observ_prompt, :production, name: "rollback-test", version: 2)

        result = Observ::PromptManager.rollback(name: "rollback-test", to_version: 1)
        expect(result.reload.state).to eq("production")
        expect(production.reload.state).to eq("archived")
      end
    end

    context "when a module is missing" do
      it "raises NoMethodError for Caching methods" do
        # This test will fail if Caching module is not loaded
        expect { Observ::PromptManager.cache_key(name: "test") }.not_to raise_error
      end

      it "raises NoMethodError for CacheStatistics methods" do
        # This test will fail if CacheStatistics module is not loaded
        expect { Observ::PromptManager.cache_stats("test") }.not_to raise_error
      end

      it "raises NoMethodError for VersionManagement methods" do
        # This test will fail if VersionManagement module is not loaded
        expect { Observ::PromptManager.versions(name: "test") }.not_to raise_error
      end

      it "raises NoMethodError for Comparison methods" do
        # This test will fail if Comparison module is not loaded
        v1 = create(:observ_prompt, name: "test", version: 1)
        v2 = create(:observ_prompt, name: "test", version: 2)

        expect {
          Observ::PromptManager.compare_versions(name: "test", version_a: 1, version_b: 2)
        }.not_to raise_error
      end
    end
  end
end
