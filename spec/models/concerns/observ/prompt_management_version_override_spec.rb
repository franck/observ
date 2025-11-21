# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::PromptManagement, "version override" do
  before do
    # Create test prompts
    create(:observ_prompt, name: "test-prompt", version: 1, state: :production, prompt: "Production prompt v1")
    create(:observ_prompt, name: "test-prompt", version: 2, state: :draft, prompt: "Draft prompt v2")

    # Setup test agent with prompt management
    stub_const("TestAgent", Class.new(BaseAgent) do
      include Observ::PromptManagement

      use_prompt_management(
        enabled: true,
        prompt_name: "test-prompt",
        fallback: "Fallback prompt"
      )

      def self.default_model
        "gpt-4o-mini"
      end
    end)

    TestAgent.reset_prompt_cache!
  end

  after do
    # Clean up thread-local storage
    Thread.current[:observ_prompt_version_override] = nil
  end

  describe ".fetch_prompt with version override" do
    it "fetches production version by default" do
      prompt = TestAgent.fetch_prompt
      expect(prompt).to eq("Production prompt v1")
    end

    it "fetches specific version when version parameter is provided" do
      prompt = TestAgent.fetch_prompt(version: 2)
      expect(prompt).to eq("Draft prompt v2")
    end

    it "fetches specific version from thread-local storage" do
      Thread.current[:observ_prompt_version_override] = 2

      prompt = TestAgent.fetch_prompt
      expect(prompt).to eq("Draft prompt v2")

      Thread.current[:observ_prompt_version_override] = nil
    end

    it "prioritizes thread-local version over parameter" do
      Thread.current[:observ_prompt_version_override] = 2

      # Even though we pass version: 1, it should use thread-local version: 2
      prompt = TestAgent.fetch_prompt(version: 1)
      expect(prompt).to eq("Draft prompt v2")

      Thread.current[:observ_prompt_version_override] = nil
    end
  end

  describe ".system_prompt with version override" do
    it "uses version from thread-local storage" do
      Thread.current[:observ_prompt_version_override] = 2

      # Clear cached system prompt
      TestAgent.reset_prompt_cache!

      system_prompt = TestAgent.system_prompt
      expect(system_prompt).to eq("Draft prompt v2")

      Thread.current[:observ_prompt_version_override] = nil
    end

    it "returns production version when no override is set" do
      TestAgent.reset_prompt_cache!

      system_prompt = TestAgent.system_prompt
      expect(system_prompt).to eq("Production prompt v1")
    end
  end

  describe ".model with version override" do
    before do
      # Create prompts with different model configurations
      Observ::Prompt.destroy_all
      Rails.cache.clear # Clear PromptManager cache

      create(:observ_prompt,
        name: "test-prompt",
        version: 1,
        state: :production,
        prompt: "Production prompt v1",
        config: { "model" => "gpt-4o-mini" })
      create(:observ_prompt,
        name: "test-prompt",
        version: 2,
        state: :draft,
        prompt: "Draft prompt v2",
        config: { "model" => "gpt-5-nano" })

      TestAgent.reset_prompt_cache!
    end

    it "fetches model from production version by default" do
      model = TestAgent.model
      expect(model).to eq("gpt-4o-mini")
    end

    it "fetches model from specific version when version parameter is provided" do
      model = TestAgent.fetch_model_from_prompt(version: 2)
      expect(model).to eq("gpt-5-nano")
    end

    it "fetches model from thread-local version override" do
      Thread.current[:observ_prompt_version_override] = 2

      model = TestAgent.model
      expect(model).to eq("gpt-5-nano")

      Thread.current[:observ_prompt_version_override] = nil
    end

    it "prioritizes thread-local version over parameter" do
      Thread.current[:observ_prompt_version_override] = 2

      # Even though we pass version: 1, it should use thread-local version: 2
      model = TestAgent.fetch_model_from_prompt(version: 1)
      expect(model).to eq("gpt-5-nano")

      Thread.current[:observ_prompt_version_override] = nil
    end

    it "falls back to default_model when prompt has no model config" do
      create(:observ_prompt,
        name: "test-prompt",
        version: 3,
        state: :draft,
        prompt: "Draft prompt v3 without model",
        config: {})

      Thread.current[:observ_prompt_version_override] = 3

      model = TestAgent.model
      expect(model).to eq("gpt-4o-mini") # Falls back to TestAgent.default_model

      Thread.current[:observ_prompt_version_override] = nil
    end
  end

  describe ".model_parameters with version override" do
    before do
      # Create prompts with different model parameter configurations
      Observ::Prompt.destroy_all
      Rails.cache.clear # Clear PromptManager cache

      create(:observ_prompt,
        name: "test-prompt",
        version: 1,
        state: :production,
        prompt: "Production prompt v1",
        config: {
          "model" => "gpt-4o-mini",
          "temperature" => 0.7,
          "max_tokens" => 1000
        })
      create(:observ_prompt,
        name: "test-prompt",
        version: 2,
        state: :draft,
        prompt: "Draft prompt v2",
        config: {
          "model" => "gpt-5-nano",
          "temperature" => 0.3,
          "max_tokens" => 2000,
          "top_p" => 0.9
        })

      TestAgent.reset_prompt_cache!

      # Add default_model_parameters to TestAgent
      TestAgent.define_singleton_method(:default_model_parameters) do
        { temperature: 0.5 }
      end
    end

    it "fetches parameters from production version by default" do
      params = TestAgent.model_parameters
      expect(params).to eq({ temperature: 0.7, max_tokens: 1000 })
    end

    it "fetches parameters from specific version when version parameter is provided" do
      params = TestAgent.fetch_model_parameters_from_prompt(version: 2)
      expect(params).to eq({ temperature: 0.3, max_tokens: 2000, top_p: 0.9 })
    end

    it "fetches parameters from thread-local version override" do
      Thread.current[:observ_prompt_version_override] = 2

      params = TestAgent.model_parameters
      expect(params).to eq({ temperature: 0.3, max_tokens: 2000, top_p: 0.9 })

      Thread.current[:observ_prompt_version_override] = nil
    end

    it "prioritizes thread-local version over parameter" do
      Thread.current[:observ_prompt_version_override] = 2

      # Even though we pass version: 1, it should use thread-local version: 2
      params = TestAgent.fetch_model_parameters_from_prompt(version: 1)
      expect(params).to eq({ temperature: 0.3, max_tokens: 2000, top_p: 0.9 })

      Thread.current[:observ_prompt_version_override] = nil
    end

    it "falls back to default_model_parameters when prompt has no parameters" do
      create(:observ_prompt,
        name: "test-prompt",
        version: 3,
        state: :draft,
        prompt: "Draft prompt v3 without params",
        config: {})

      Thread.current[:observ_prompt_version_override] = 3

      params = TestAgent.model_parameters
      expect(params).to eq({ temperature: 0.5 }) # Falls back to TestAgent.default_model_parameters

      Thread.current[:observ_prompt_version_override] = nil
    end

    it "correctly converts string numbers to numeric types" do
      create(:observ_prompt,
        name: "test-prompt",
        version: 4,
        state: :draft,
        prompt: "Draft prompt v4",
        config: {
          "temperature" => "0.8",
          "max_tokens" => "1500"
        })

      Thread.current[:observ_prompt_version_override] = 4

      params = TestAgent.model_parameters
      expect(params[:temperature]).to eq(0.8)
      expect(params[:temperature]).to be_a(Float)
      expect(params[:max_tokens]).to eq(1500)
      expect(params[:max_tokens]).to be_a(Integer)

      Thread.current[:observ_prompt_version_override] = nil
    end
  end
end
