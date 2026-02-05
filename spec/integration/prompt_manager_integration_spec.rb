# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/dummy_agent'

RSpec.describe "PromptManager Integration" do
  before do
    Rails.cache.clear
  end

  describe "module loading and availability" do
    it "loads all required PromptManager modules" do
      # If any module is missing, these method calls will raise NoMethodError
      expect { Observ::PromptManager.cache_key(name: "test") }.not_to raise_error
      expect { Observ::PromptManager.cache_stats("test") }.not_to raise_error
      expect { Observ::PromptManager.versions(name: "test") }.not_to raise_error

      # This will only work if all modules are loaded
      v1 = create(:observ_prompt, name: "test", version: 1)
      v2 = create(:observ_prompt, name: "test", version: 2)
      expect { Observ::PromptManager.compare_versions(name: "test", version_a: 1, version_b: 2) }.not_to raise_error
    end

    it "provides all Caching module methods" do
      expect(Observ::PromptManager).to respond_to(:fetch)
      expect(Observ::PromptManager).to respond_to(:fetch_all)
      expect(Observ::PromptManager).to respond_to(:cache_key)
      expect(Observ::PromptManager).to respond_to(:invalidate_cache)
      expect(Observ::PromptManager).to respond_to(:warm_cache)
    end

    it "provides all CacheStatistics module methods" do
      expect(Observ::PromptManager).to respond_to(:cache_stats)
      expect(Observ::PromptManager).to respond_to(:clear_stats)
    end

    it "provides all VersionManagement module methods" do
      expect(Observ::PromptManager).to respond_to(:create)
      expect(Observ::PromptManager).to respond_to(:versions)
      expect(Observ::PromptManager).to respond_to(:promote)
      expect(Observ::PromptManager).to respond_to(:demote)
      expect(Observ::PromptManager).to respond_to(:rollback)
      expect(Observ::PromptManager).to respond_to(:restore)
    end

    it "provides all Comparison module methods" do
      expect(Observ::PromptManager).to respond_to(:compare_versions)
    end
  end

  describe "agent integration with DummyAgent" do
    let(:dummy_agent_class) do
      Class.new(DummyAgent) do
        def self.name
          "TestDummyAgent"
        end
      end
    end

    before do
      dummy_agent_class.use_prompt_management(
        prompt_name: "test-agent-prompt",
        fallback: "Fallback prompt text"
      )
      allow(Observ.config).to receive(:prompt_management_enabled).and_return(true)
    end

    context "when PromptManager modules are loaded correctly" do
      it "can fetch prompts without errors" do
        # This will fail with NoMethodError if Caching module is not loaded
        expect {
          dummy_agent_class.fetch_prompt
        }.not_to raise_error
      end

      it "returns fallback when prompt doesn't exist" do
        result = dummy_agent_class.fetch_prompt
        expect(result).to eq("Fallback prompt text")
      end

      it "fetches production prompt when it exists" do
        create(:observ_prompt,
          :production,
          name: "test-agent-prompt",
          prompt: "Production prompt content"
        )

        result = dummy_agent_class.fetch_prompt
        expect(result).to eq("Production prompt content")
      end

      it "compiles prompt with variables" do
        create(:observ_prompt,
          :production,
          name: "test-agent-prompt",
          prompt: "Hello {{name}}, welcome to {{place}}!"
        )

        result = dummy_agent_class.fetch_prompt(variables: { name: "Alice", place: "Wonderland" })
        expect(result).to eq("Hello Alice, welcome to Wonderland!")
      end

      it "handles cache operations" do
        prompt = create(:observ_prompt,
          :production,
          name: "test-agent-prompt",
          prompt: "Cached prompt"
        )

        # This uses PromptManager.fetch which uses cache_key from Caching module
        first_fetch = dummy_agent_class.fetch_prompt

        # This uses invalidate_cache from Caching module
        Observ::PromptManager.invalidate_cache(name: "test-agent-prompt")

        second_fetch = dummy_agent_class.fetch_prompt

        expect(first_fetch).to eq("Cached prompt")
        expect(second_fetch).to eq("Cached prompt")
      end

      it "tracks cache statistics" do
        create(:observ_prompt,
          :production,
          name: "test-agent-prompt",
          prompt: "Stats test"
        )

        # Enable caching for this test
        allow(Observ.config).to receive(:prompt_cache_ttl).and_return(300)
        allow(Observ.config).to receive(:prompt_cache_monitoring_enabled).and_return(true)

        # Fetch to generate stats
        dummy_agent_class.fetch_prompt

        # This uses cache_stats from CacheStatistics module
        stats = Observ::PromptManager.cache_stats("test-agent-prompt")

        expect(stats).to be_a(Hash)
        expect(stats).to have_key(:name)
        expect(stats).to have_key(:hits)
        expect(stats).to have_key(:misses)
        expect(stats).to have_key(:hit_rate)
      end

      it "converts string model parameters to proper numeric types" do
        # Create prompt with model parameters as strings (as they come from JSON)
        create(:observ_prompt,
          :production,
          name: "test-agent-prompt",
          prompt: "Test prompt",
          config: {
            "model" => "gpt-4",
            "temperature" => "0.7",
            "max_tokens" => "2000",
            "top_p" => "0.9",
            "frequency_penalty" => "0.5",
            "presence_penalty" => "0.3"
          }
        )

        # Fetch model parameters through PromptManagement concern
        params = dummy_agent_class.model_parameters

        # Verify parameters are converted to proper numeric types
        expect(params[:temperature]).to eq(0.7)
        expect(params[:temperature]).to be_a(Float)

        expect(params[:max_tokens]).to eq(2000)
        expect(params[:max_tokens]).to be_a(Integer)

        expect(params[:top_p]).to eq(0.9)
        expect(params[:top_p]).to be_a(Float)

        expect(params[:frequency_penalty]).to eq(0.5)
        expect(params[:frequency_penalty]).to be_a(Float)

        expect(params[:presence_penalty]).to eq(0.3)
        expect(params[:presence_penalty]).to be_a(Float)
      end

      it "preserves non-numeric parameter values" do
        create(:observ_prompt,
          :production,
          name: "test-agent-prompt",
          prompt: "Test prompt",
          config: {
            "model" => "gpt-4",
            "temperature" => "0.7",
            "stop" => ["END", "STOP"]
          }
        )

        params = dummy_agent_class.model_parameters

        # Numeric values should be converted
        expect(params[:temperature]).to eq(0.7)
        expect(params[:temperature]).to be_a(Float)

        # Non-numeric values should be preserved
        expect(params[:stop]).to eq(["END", "STOP"])
        expect(params[:stop]).to be_a(Array)
      end
    end

    context "when PromptManager.fetch fails" do
      before do
        allow(Observ::PromptManager).to receive(:fetch).and_raise(StandardError, "Database connection error")
      end

      it "falls back gracefully" do
        expect(Rails.logger).to receive(:error).with(/Failed to fetch prompt/)

        result = dummy_agent_class.fetch_prompt
        expect(result).to eq("Fallback prompt text")
      end
    end
  end

  describe "full workflow integration" do
    let(:dummy_agent_class) do
      Class.new(DummyAgent) do
        def self.name
          "WorkflowAgent"
        end
      end
    end

    before do
      dummy_agent_class.use_prompt_management(
        prompt_name: "workflow-agent-prompt",
        fallback: "Fallback"
      )
      allow(Observ.config).to receive(:prompt_management_enabled).and_return(true)
    end

    it "supports complete version management workflow" do
      # Create initial version (uses VersionManagement.create)
      v1 = Observ::PromptManager.create(
        name: "workflow-agent-prompt",
        prompt: "Version 1 content",
        config: { model: "gpt-4" }
      )
      expect(v1.version).to eq(1)
      expect(v1.state).to eq("draft")

      # Promote to production (uses VersionManagement.promote)
      Observ::PromptManager.promote(name: "workflow-agent-prompt", version: 1)
      expect(v1.reload.state).to eq("production")

      # Agent can now fetch it
      result = dummy_agent_class.fetch_prompt
      expect(result).to eq("Version 1 content")

      # Create version 2 (uses VersionManagement.create)
      v2 = Observ::PromptManager.create(
        name: "workflow-agent-prompt",
        prompt: "Version 2 content",
        config: { model: "gpt-4" },
        promote_to_production: true
      )
      expect(v2.version).to eq(2)
      expect(v2.state).to eq("production")
      expect(v1.reload.state).to eq("archived")

      # Agent fetches new version
      Observ::PromptManager.invalidate_cache(name: "workflow-agent-prompt")
      result = dummy_agent_class.fetch_prompt
      expect(result).to eq("Version 2 content")

      # Compare versions (uses Comparison.compare_versions)
      comparison = Observ::PromptManager.compare_versions(
        name: "workflow-agent-prompt",
        version_a: 1,
        version_b: 2
      )
      expect(comparison[:from].version).to eq(1)
      expect(comparison[:to].version).to eq(2)
      expect(comparison[:diff][:changed]).to be true

      # Rollback (uses VersionManagement.rollback)
      Observ::PromptManager.rollback(name: "workflow-agent-prompt", to_version: 1)
      expect(v1.reload.state).to eq("production")
      expect(v2.reload.state).to eq("archived")

      # Agent fetches rolled back version
      Observ::PromptManager.invalidate_cache(name: "workflow-agent-prompt")
      result = dummy_agent_class.fetch_prompt
      expect(result).to eq("Version 1 content")
    end
  end
end
