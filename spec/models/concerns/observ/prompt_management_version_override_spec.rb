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
end
