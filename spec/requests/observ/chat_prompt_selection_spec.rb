# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Chat prompt version selection" do
  let!(:prompt_v1) { create(:observ_prompt, name: "dummy-agent-system-prompt", version: 1, state: :production, prompt: "Production v1") }
  let!(:prompt_v2) { create(:observ_prompt, name: "dummy-agent-system-prompt", version: 2, state: :draft, prompt: "Draft v2") }

  before do
    # Ensure DummyAgent is loaded and uses prompt management
    DummyAgent.use_prompt_management(enabled: true, prompt_name: "dummy-agent-system-prompt")
    DummyAgent.reset_prompt_cache!
  end

  describe "ChatsController#set_prompt_info_from_agent" do
    it "sets prompt_name from agent configuration" do
      chat = Chat.new(agent_class_name: "DummyAgent")

      # Simulate what the controller does
      agent_class = chat.agent_class_name.constantize
      if agent_class.included_modules.include?(Observ::PromptManagement) &&
         agent_class.respond_to?(:prompt_management_enabled?) &&
         agent_class.prompt_management_enabled?
        chat.prompt_name = agent_class.prompt_config[:prompt_name]
      end

      expect(chat.prompt_name).to eq("dummy-agent-system-prompt")
    end

    it "does not set prompt_name for agents without prompt management" do
      # Create an agent class without prompt management
      stub_const("SimpleAgent", Class.new(BaseAgent) do
        include Observ::AgentSelectable

        def self.system_prompt
          "I am simple"
        end

        def self.default_model
          "gpt-4o-mini"
        end

        def self.display_name
          "Simple Agent"
        end

        def self.description
          "Simple test agent"
        end
      end)

      chat = Chat.new(agent_class_name: "SimpleAgent")

      # Simulate what the controller does
      agent_class = chat.agent_class_name.constantize
      if agent_class.included_modules.include?(Observ::PromptManagement) &&
         agent_class.respond_to?(:prompt_management_enabled?) &&
         agent_class.prompt_management_enabled?
        chat.prompt_name = agent_class.prompt_config[:prompt_name]
      end

      expect(chat.prompt_name).to be_nil
    end
  end

  describe "prompt version persistence" do
    it "stores prompt_name and prompt_version fields" do
      chat = Chat.create!(
        agent_class_name: "DummyAgent",
        prompt_version: 2,
        prompt_name: "dummy-agent-system-prompt"
      )

      expect(chat.reload.prompt_version).to eq(2)
      expect(chat.prompt_name).to eq("dummy-agent-system-prompt")
    end

    it "allows nil prompt_version for default behavior" do
      chat = Chat.create!(
        agent_class_name: "DummyAgent",
        prompt_name: "dummy-agent-system-prompt"
      )

      expect(chat.reload.prompt_version).to be_nil
      expect(chat.prompt_name).to eq("dummy-agent-system-prompt")
    end
  end
end
