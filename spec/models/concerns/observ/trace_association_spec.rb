require 'rails_helper'

RSpec.describe Observ::TraceAssociation, type: :concern do
  let(:test_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'messages'
      include Observ::TraceAssociation
    end
  end

  describe 'associations' do
    it 'includes has_many :traces association' do
      association = test_class.reflect_on_association(:traces)
      expect(association).to be_present
      expect(association.macro).to eq(:has_many)
    end

    it 'configures traces with correct class_name' do
      association = test_class.reflect_on_association(:traces)
      expect(association.class_name).to eq('Observ::Trace')
    end

    it 'configures traces with dependent: :nullify' do
      association = test_class.reflect_on_association(:traces)
      expect(association.options[:dependent]).to eq(:nullify)
    end
  end

  describe 'behavior with Message model', observability: true do
    let(:chat) { create(:chat) }
    let!(:message) { chat.messages.create!(role: "user", content: "Hello world") }

    it 'can have multiple traces' do
      trace1 = create(:observ_trace, message: message)
      trace2 = create(:observ_trace, message: message)

      expect(message.traces.count).to eq(2)
      expect(message.traces).to include(trace1, trace2)
    end

    it 'nullifies traces when message is destroyed' do
      trace = create(:observ_trace, message: message)
      trace_id = trace.id
      message.destroy

      trace.reload
      expect(trace.message_id).to be_nil
    end
  end
end
