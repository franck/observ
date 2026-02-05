require 'rails_helper'

RSpec.describe Observ::ChatsHelper, type: :helper do
  describe '#agent_select_options' do
    it 'returns formatted options for select dropdown' do
      options = helper.agent_select_options

      expect(options).to be_an(Array)
      expect(options).not_to be_empty
    end

    it 'includes default option as first element' do
      options = helper.agent_select_options

      expect(options.first).to eq(["Default Agent", ""])
    end

    it 'delegates to AgentSelectionService' do
      mock_options = [["Default Agent", ""], ["Test", "TestAgent"]]

      allow(Observ::AgentSelectionService).to receive(:options).and_return(mock_options)

      result = helper.agent_select_options

      expect(result).to eq(mock_options)
    end

    it 'memoizes the result' do
      expect(Observ::AgentSelectionService).to receive(:options).once.and_call_original

      # Call twice
      helper.agent_select_options
      helper.agent_select_options
    end

    it 'returns correctly formatted options' do
      options = helper.agent_select_options

      options.each do |option|
        expect(option).to be_an(Array)
        expect(option.size).to eq(2)
        expect(option[0]).to be_a(String)
        expect(option[1]).to be_a(String)
      end
    end
  end

  describe '#agents_with_prompts_map' do
    before do
      # Ensure DummyAgent uses prompt management
      DummyAgent.use_prompt_management(enabled: true, prompt_name: "dummy-agent-system-prompt")
    end

    it 'returns a hash mapping agent class names to prompt names' do
      result = helper.agents_with_prompts_map

      expect(result).to be_a(Hash)
    end

    it 'includes agents that use prompt management' do
      result = helper.agents_with_prompts_map

      expect(result).to include("DummyAgent" => "dummy-agent-system-prompt")
    end

    it 'excludes agents that do not use prompt management' do
      # Create a test agent without prompt management
      stub_const("NonPromptAgent", Class.new(BaseAgent) do
        include Observ::AgentSelectable

        def self.system_prompt
          "I am a test agent"
        end

        def self.default_model
          "gpt-4o-mini"
        end

        def self.display_name
          "Non Prompt Agent"
        end

        def self.description
          "Test agent without prompt management"
        end
      end)

      result = helper.agents_with_prompts_map

      expect(result).not_to have_key("NonPromptAgent")
    end

    it 'memoizes the result' do
      expect(Observ::AgentProvider).to receive(:all_agents).once.and_call_original

      # Call twice
      helper.agents_with_prompts_map
      helper.agents_with_prompts_map
    end

    it 'only includes agents with prompt management enabled' do
      # Temporarily disable prompt management for DummyAgent
      DummyAgent.use_prompt_management(enabled: false)

      result = helper.agents_with_prompts_map

      expect(result).not_to have_key("DummyAgent")

      # Re-enable for other tests
      DummyAgent.use_prompt_management(enabled: true, prompt_name: "dummy-agent-system-prompt")
    end
  end
end
