# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::ChatEnhancements do
  before do
    # Create test prompts with different model configurations
    Observ::Prompt.destroy_all
    Rails.cache.clear

    create(:observ_prompt,
      name: "dummy-agent-system-prompt",
      version: 1,
      state: :production,
      prompt: "Production prompt v1",
      config: { "model" => "gpt-4o-mini", "temperature" => 0.7 })
    create(:observ_prompt,
      name: "dummy-agent-system-prompt",
      version: 2,
      state: :draft,
      prompt: "Draft prompt v2",
      config: { "model" => "gpt-5-nano", "temperature" => 0.3 })

    # Setup DummyAgent with prompt management
    DummyAgent.use_prompt_management(enabled: true, prompt_name: "dummy-agent-system-prompt")
    DummyAgent.reset_prompt_cache!
  end

  after do
    Thread.current[:observ_prompt_version_override] = nil
  end

  describe "#set_model_from_agent" do
    context "when chat has a prompt_version specified" do
      it "sets the model from the specified prompt version" do
        chat = Chat.new(
          agent_class_name: "DummyAgent",
          prompt_version: 2,
          prompt_name: "dummy-agent-system-prompt"
        )

        # The before_save callback should set @model_string
        chat.send(:set_model_from_agent)

        expect(chat.instance_variable_get(:@model_string)).to eq("gpt-5-nano")
      end

      it "clears the thread-local version override after setting the model" do
        chat = Chat.new(
          agent_class_name: "DummyAgent",
          prompt_version: 2,
          prompt_name: "dummy-agent-system-prompt"
        )

        chat.send(:set_model_from_agent)

        expect(Thread.current[:observ_prompt_version_override]).to be_nil
      end
    end

    context "when chat has no prompt_version specified" do
      it "sets the model from the production prompt version" do
        chat = Chat.new(
          agent_class_name: "DummyAgent",
          prompt_name: "dummy-agent-system-prompt"
        )

        chat.send(:set_model_from_agent)

        expect(chat.instance_variable_get(:@model_string)).to eq("gpt-4o-mini")
      end
    end

    context "when agent does not include PromptManagement" do
      before do
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
      end

      it "sets the model from the agent's default_model" do
        # Create a chat class that uses SimpleAgent
        chat = Chat.new(agent_class_name: "SimpleAgent")

        # Override agent_class to return SimpleAgent
        allow(chat).to receive(:agent_class).and_return(SimpleAgent)

        chat.send(:set_model_from_agent)

        expect(chat.instance_variable_get(:@model_string)).to eq("gpt-4o-mini")
      end

      it "does not set thread-local version override" do
        chat = Chat.new(agent_class_name: "SimpleAgent", prompt_version: 2)

        allow(chat).to receive(:agent_class).and_return(SimpleAgent)

        chat.send(:set_model_from_agent)

        expect(Thread.current[:observ_prompt_version_override]).to be_nil
      end
    end
  end

  describe "#ensure_agent_configured" do
    context "when chat has a prompt_version specified" do
      it "sets the thread-local version override during configuration" do
        chat = Chat.create!(
          agent_class_name: "DummyAgent",
          prompt_version: 2,
          prompt_name: "dummy-agent-system-prompt"
        )

        # Reset the configured flag to test ensure_agent_configured
        chat.instance_variable_set(:@_agent_params_configured, false)

        version_during_config = nil
        allow(DummyAgent).to receive(:setup_parameters) do |_chat|
          version_during_config = Thread.current[:observ_prompt_version_override]
        end

        chat.ensure_agent_configured

        expect(version_during_config).to eq(2)
      end

      it "clears the thread-local version override after configuration" do
        chat = Chat.create!(
          agent_class_name: "DummyAgent",
          prompt_version: 2,
          prompt_name: "dummy-agent-system-prompt"
        )

        chat.instance_variable_set(:@_agent_params_configured, false)
        chat.ensure_agent_configured

        expect(Thread.current[:observ_prompt_version_override]).to be_nil
      end
    end
  end

  describe "#observability_context" do
    it "includes prompt_version_override when prompt_version is set" do
      chat = Chat.create!(
        agent_class_name: "DummyAgent",
        prompt_version: 2,
        prompt_name: "dummy-agent-system-prompt"
      )

      context = chat.send(:observability_context)

      expect(context[:prompt_version_override]).to eq(2)
    end

    it "does not include prompt_version_override when prompt_version is nil" do
      chat = Chat.create!(
        agent_class_name: "DummyAgent",
        prompt_name: "dummy-agent-system-prompt"
      )

      context = chat.send(:observability_context)

      expect(context[:prompt_version_override]).to be_nil
    end
  end
end
