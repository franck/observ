# frozen_string_literal: true

require 'rails_helper'

# Smoke tests to ensure critical components load correctly
# These tests should catch missing modules or broken dependencies
RSpec.describe "Observ Engine Smoke Tests" do
  describe "critical modules and classes load" do
    it "loads Observ::Engine" do
      expect(Observ::Engine).to be_a(Class)
    end

    it "loads Observ::PromptManager" do
      expect(Observ::PromptManager).to be_a(Class)
    end

    it "loads all PromptManager concern modules" do
      expect(defined?(Observ::PromptManager::Caching)).to be_truthy
      expect(defined?(Observ::PromptManager::CacheStatistics)).to be_truthy
      expect(defined?(Observ::PromptManager::VersionManagement)).to be_truthy
      expect(defined?(Observ::PromptManager::Comparison)).to be_truthy
    end

    it "loads Observ models" do
      expect(Observ::Prompt).to be_a(Class)
      expect(Observ::Session).to be_a(Class)
      expect(Observ::Trace).to be_a(Class)
      expect(Observ::Observation).to be_a(Class)
      expect(Observ::Generation).to be_a(Class)
      expect(Observ::Span).to be_a(Class)
      expect(Observ::Annotation).to be_a(Class)
    end

    it "loads Observ services" do
      expect(Observ::ChatInstrumenter).to be_a(Class)
      expect(Observ::AgentSelectionService).to be_a(Class)
    end

    it "loads Observ concerns" do
      expect(defined?(Observ::ObservabilityInstrumentation)).to be_truthy
      expect(defined?(Observ::TraceAssociation)).to be_truthy
    end
  end

  describe "PromptManager provides all required methods" do
    it "provides Caching methods" do
      %i[fetch fetch_all cache_key invalidate_cache warm_cache].each do |method|
        expect(Observ::PromptManager).to respond_to(method),
          "Expected PromptManager to respond to #{method} (from Caching module)"
      end
    end

    it "provides CacheStatistics methods" do
      %i[cache_stats clear_stats].each do |method|
        expect(Observ::PromptManager).to respond_to(method),
          "Expected PromptManager to respond to #{method} (from CacheStatistics module)"
      end
    end

    it "provides VersionManagement methods" do
      %i[create versions promote demote rollback restore].each do |method|
        expect(Observ::PromptManager).to respond_to(method),
          "Expected PromptManager to respond to #{method} (from VersionManagement module)"
      end
    end

    it "provides Comparison methods" do
      expect(Observ::PromptManager).to respond_to(:compare_versions),
        "Expected PromptManager to respond to compare_versions (from Comparison module)"
    end
  end

  describe "PromptManager can perform basic operations" do
    it "can generate cache keys" do
      key = Observ::PromptManager.cache_key(name: "test", state: :production)
      expect(key).to be_a(String)
      expect(key).to include("test")
    end

    it "can fetch with fallback" do
      result = Observ::PromptManager.fetch(
        name: "nonexistent",
        state: :production,
        fallback: "fallback"
      )
      expect(result).to be_a(Observ::NullPrompt)
      expect(result.prompt).to eq("fallback")
      expect(result.version).to be_nil
    end

    it "can create prompts" do
      prompt = Observ::PromptManager.create(
        name: "smoke-test-prompt",
        prompt: "Test",
        config: {}
      )
      expect(prompt).to be_persisted
    end
  end

  describe "configuration is accessible" do
    it "provides Observ.config" do
      expect(Observ.config).to be_present
    end

    it "has prompt management configuration" do
      expect(Observ.config).to respond_to(:prompt_management_enabled)
      expect(Observ.config).to respond_to(:prompt_cache_ttl)
      expect(Observ.config).to respond_to(:prompt_cache_namespace)
    end
  end
end
