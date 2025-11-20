require 'rails_helper'

RSpec.describe Observ::AgentSelectPresenter do
  describe '#initialize' do
    it 'accepts agents via dependency injection' do
      mock_agents = [ double(display_name: 'Test', agent_identifier: 'Test') ]
      presenter = described_class.new(agents: mock_agents)

      expect(presenter.agents).to eq(mock_agents)
    end
  end

  describe '#options' do
    it 'returns an array of options' do
      mock_agents = []
      presenter = described_class.new(agents: mock_agents)

      expect(presenter.options).to be_an(Array)
    end

    it 'includes default option as first element' do
      mock_agents = []
      presenter = described_class.new(agents: mock_agents)

      expect(presenter.options.first).to eq([ 'Default Agent', '' ])
    end

    it 'formats injected agents correctly' do
      mock_agents = [
        double(display_name: 'Agent One', agent_identifier: 'AgentOne'),
        double(display_name: 'Agent Two', agent_identifier: 'AgentTwo')
      ]
      presenter = described_class.new(agents: mock_agents)

      options = presenter.options

      expect(options).to eq([
        [ 'Default Agent', '' ],
        [ 'Agent One', 'AgentOne' ],
        [ 'Agent Two', 'AgentTwo' ]
      ])
    end

    it 'works with real agent classes' do
      agents = Observ::AgentProvider.all_agents
      presenter = described_class.new(agents: agents)

      options = presenter.options

      expect(options.first).to eq([ 'Default Agent', '' ])
      expect(options.count).to eq(agents.count + 1)
    end
  end

  describe '.options' do
    it 'provides convenience class method' do
      options = described_class.options

      expect(options).to be_an(Array)
      expect(options.first).to eq([ 'Default Agent', '' ])
    end

    it 'accepts optional agents parameter' do
      mock_agents = [
        double(display_name: 'Mock', agent_identifier: 'Mock')
      ]

      options = described_class.options(agents: mock_agents)

      expect(options).to eq([
        [ 'Default Agent', '' ],
        [ 'Mock', 'Mock' ]
      ])
    end
  end
end
