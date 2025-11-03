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

      expect(options.first).to eq([ "Default Agent", "" ])
    end

    it 'delegates to AgentSelectionService' do
      mock_options = [ [ "Default Agent", "" ], [ "Test", "TestAgent" ] ]

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
end
