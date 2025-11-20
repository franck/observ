require 'rails_helper'

RSpec.describe Observ::AgentSelectionService do
  describe '.options' do
    it 'returns formatted options for select dropdown' do
      options = described_class.options

      expect(options).to be_an(Array)
      expect(options).not_to be_empty
    end

    it 'includes default option as first element' do
      options = described_class.options

      expect(options.first).to eq([ "Default Agent", "" ])
    end

    it 'includes agent options after default' do
      options = described_class.options

      expect(options.count).to be > 1
      expect(options[1]).to be_an(Array)
      expect(options[1].size).to eq(2) # [display_name, identifier]
    end

    it 'delegates to AgentSelectPresenter with agents from AgentProvider' do
      mock_agents = [
        double(display_name: "Test Agent", agent_identifier: "TestAgent")
      ]

      allow(Observ::AgentProvider).to receive(:all_agents).and_return(mock_agents)

      expect(Observ::AgentSelectPresenter).to receive(:options)
        .with(agents: mock_agents)
        .and_call_original

      described_class.options
    end

    it 'returns correctly formatted options' do
      options = described_class.options

      options.each do |option|
        expect(option).to be_an(Array)
        expect(option.size).to eq(2)
        expect(option[0]).to be_a(String) # display_name
        expect(option[1]).to be_a(String) # identifier
      end
    end
  end

  describe '.all_agents' do
    it 'delegates to AgentProvider' do
      expect(Observ::AgentProvider).to receive(:all_agents).and_call_original

      described_class.all_agents
    end

    it 'returns array of agent classes' do
      agents = described_class.all_agents

      expect(agents).to be_an(Array)
      expect(agents).to all(be_a(Class))
    end

    it 'returns agents that include AgentSelectable' do
      agents = described_class.all_agents

      agents.each do |agent|
        expect(agent.ancestors).to include(Observ::AgentSelectable)
      end
    end

    it 'returns the same result as AgentProvider.all_agents' do
      direct_result = Observ::AgentProvider.all_agents
      service_result = described_class.all_agents

      expect(service_result).to eq(direct_result)
    end
  end
end
