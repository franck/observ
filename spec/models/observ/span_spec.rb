require 'rails_helper'

RSpec.describe Observ::Span, type: :model do
  describe '#finalize' do
    let(:span) { create(:observ_span) }

    it 'sets output' do
      span.finalize(output: 'span result')
      expect(span.output).to eq('span result')
    end

    it 'sets status_message' do
      span.finalize(status_message: 'completed successfully')
      expect(span.status_message).to eq('completed successfully')
    end

    it 'sets end_time' do
      span.finalize(output: 'done')
      expect(span.end_time).to be_present
      expect(span.end_time).to be_within(1.second).of(Time.current)
    end

    it 'converts hash output to JSON' do
      span.finalize(output: { status: 'ok', data: [ 1, 2, 3 ] })
      expect(span.output).to be_a(String)
      expect(JSON.parse(span.output)).to eq({ 'status' => 'ok', 'data' => [ 1, 2, 3 ] })
    end
  end

  describe 'tool span' do
    it 'can be created with tool: prefix' do
      span = create(:observ_span, name: 'tool:weather')
      expect(span.name).to eq('tool:weather')
    end

    it 'can store tool arguments in input' do
      span = create(:observ_span, input: { city: 'Paris', units: 'metric' }.to_json)
      parsed = JSON.parse(span.input)
      expect(parsed['city']).to eq('Paris')
      expect(parsed['units']).to eq('metric')
    end
  end

  describe 'error span' do
    let(:error_span) { create(:observ_span, :error) }

    it 'can be created with error name' do
      expect(error_span.name).to eq('error')
      expect(error_span.level).to eq('ERROR')
    end

    it 'stores error information in input' do
      parsed = JSON.parse(error_span.input)
      expect(parsed['error_type']).to eq('StandardError')
      expect(parsed['error_message']).to eq('Test error')
    end
  end
end
