require 'rails_helper'

RSpec.describe Observ::ImageGeneration, type: :model do
  describe '#finalize' do
    let(:image_generation) { create(:observ_image_generation) }

    it 'sets all image-specific fields' do
      image_generation.finalize(
        output: { model: 'dall-e-3', has_url: true },
        cost_usd: 0.04
      )

      expect(JSON.parse(image_generation.output)).to include('model' => 'dall-e-3')
      expect(image_generation.cost_usd).to eq(0.04)
      expect(image_generation.end_time).to be_present
    end

    it 'merges usage with existing usage' do
      image_generation.usage = { existing: 'data' }
      image_generation.finalize(
        output: 'test',
        usage: { image_count: 1 }
      )
      expect(image_generation.usage).to include('existing' => 'data', 'image_count' => 1)
    end

    it 'converts hash output to JSON' do
      image_generation.finalize(output: { result: 'success' })
      expect(image_generation.output).to be_a(String)
      expect(JSON.parse(image_generation.output)).to eq({ 'result' => 'success' })
    end

    it 'sets status_message when provided' do
      image_generation.finalize(output: 'test', status_message: 'COMPLETED')
      expect(image_generation.status_message).to eq('COMPLETED')
    end
  end

  describe '#size' do
    it 'returns size from metadata' do
      image_generation = create(:observ_image_generation, metadata: { size: '1792x1024' })
      expect(image_generation.size).to eq('1792x1024')
    end

    it 'returns nil when size not set' do
      image_generation = create(:observ_image_generation, metadata: {})
      expect(image_generation.size).to be_nil
    end
  end

  describe '#quality' do
    it 'returns quality from metadata' do
      image_generation = create(:observ_image_generation, metadata: { quality: 'hd' })
      expect(image_generation.quality).to eq('hd')
    end

    it 'returns nil when quality not set' do
      image_generation = create(:observ_image_generation, metadata: {})
      expect(image_generation.quality).to be_nil
    end
  end

  describe '#revised_prompt' do
    it 'returns revised_prompt from metadata' do
      image_generation = create(:observ_image_generation, :with_revised_prompt)
      expect(image_generation.revised_prompt).to start_with('A detailed')
    end

    it 'returns nil when revised_prompt not set' do
      image_generation = create(:observ_image_generation, metadata: {})
      expect(image_generation.revised_prompt).to be_nil
    end
  end

  describe '#output_format' do
    it 'returns output_format from metadata' do
      image_generation = create(:observ_image_generation, metadata: { output_format: 'url' })
      expect(image_generation.output_format).to eq('url')
    end

    it 'returns base64 for base64 images' do
      image_generation = create(:observ_image_generation, :base64)
      expect(image_generation.output_format).to eq('base64')
    end
  end

  describe '#mime_type' do
    it 'returns mime_type from metadata' do
      image_generation = create(:observ_image_generation, metadata: { mime_type: 'image/png' })
      expect(image_generation.mime_type).to eq('image/png')
    end

    it 'returns nil when mime_type not set' do
      image_generation = create(:observ_image_generation, metadata: {})
      expect(image_generation.mime_type).to be_nil
    end
  end

  describe 'STI type' do
    it 'has the correct type' do
      image_generation = create(:observ_image_generation)
      expect(image_generation.type).to eq('Observ::ImageGeneration')
    end

    it 'is a subclass of Observation' do
      expect(Observ::ImageGeneration.superclass).to eq(Observ::Observation)
    end
  end

  describe 'finalized trait' do
    let(:image_generation) { create(:observ_image_generation, :finalized) }

    it 'has end_time set' do
      expect(image_generation.end_time).to be_present
    end

    it 'has output set' do
      expect(image_generation.output).to be_present
    end
  end
end
