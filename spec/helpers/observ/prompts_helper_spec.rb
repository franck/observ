require 'rails_helper'

RSpec.describe Observ::PromptsHelper, type: :helper do
  describe '#chat_model_options_grouped' do
    context 'when RubyLLM is available with models' do
      before do
        model1 = double('Model', provider: 'openai', display_name: 'GPT-4o', id: 'gpt-4o')
        model2 = double('Model', provider: 'openai', display_name: 'GPT-4o Mini', id: 'gpt-4o-mini')
        model3 = double('Model', provider: 'anthropic', display_name: 'Claude 3.5 Sonnet', id: 'claude-3-5-sonnet')
        models_collection = double('ModelsCollection', chat_models: [model1, model2, model3])

        stub_const('RubyLLM', double('RubyLLM', models: models_collection))
        allow(RubyLLM).to receive(:respond_to?).with(:models).and_return(true)
      end

      it 'returns models grouped by provider' do
        result = helper.chat_model_options_grouped

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
      end

      it 'sorts providers alphabetically' do
        result = helper.chat_model_options_grouped

        expect(result[0][0]).to eq('Anthropic')
        expect(result[1][0]).to eq('Openai')
      end

      it 'includes display name and id for each model' do
        result = helper.chat_model_options_grouped

        anthropic_models = result.find { |p, _| p == 'Anthropic' }[1]
        expect(anthropic_models).to include(['Claude 3.5 Sonnet', 'claude-3-5-sonnet'])
      end

      it 'sorts models by display name within each provider' do
        result = helper.chat_model_options_grouped

        openai_models = result.find { |p, _| p == 'Openai' }[1]
        expect(openai_models[0][0]).to eq('GPT-4o')
        expect(openai_models[1][0]).to eq('GPT-4o Mini')
      end
    end

    context 'when RubyLLM is not defined' do
      before do
        hide_const('RubyLLM')
      end

      it 'returns an empty array' do
        result = helper.chat_model_options_grouped

        expect(result).to eq([])
      end
    end

    context 'when RubyLLM does not respond to models' do
      before do
        stub_const('RubyLLM', double('RubyLLM'))
        allow(RubyLLM).to receive(:respond_to?).with(:models).and_return(false)
      end

      it 'returns an empty array' do
        result = helper.chat_model_options_grouped

        expect(result).to eq([])
      end
    end

    context 'when an error occurs' do
      before do
        stub_const('RubyLLM', double('RubyLLM'))
        allow(RubyLLM).to receive(:respond_to?).with(:models).and_return(true)
        allow(RubyLLM).to receive(:models).and_raise(StandardError, 'API error')
      end

      it 'returns an empty array and logs a warning' do
        expect(Rails.logger).to receive(:warn).with(/Failed to load RubyLLM models/)

        result = helper.chat_model_options_grouped

        expect(result).to eq([])
      end
    end
  end

  describe '#config_value' do
    context 'with a Prompt model' do
      let(:prompt) { build(:observ_prompt, config: { 'model' => 'gpt-4o', 'temperature' => 0.7 }) }

      it 'returns value for string key' do
        result = helper.config_value(prompt, 'model')

        expect(result).to eq('gpt-4o')
      end

      it 'returns value for symbol key' do
        result = helper.config_value(prompt, :temperature)

        expect(result).to eq(0.7)
      end

      it 'returns default when key is not present' do
        result = helper.config_value(prompt, :max_tokens, 2000)

        expect(result).to eq(2000)
      end

      it 'returns nil when key is not present and no default' do
        result = helper.config_value(prompt, :missing_key)

        expect(result).to be_nil
      end
    end

    context 'with a PromptForm' do
      let(:form) { Observ::PromptForm.new(config: '{"model": "claude-3-5-sonnet", "max_tokens": 4000}') }

      it 'returns value for string key' do
        result = helper.config_value(form, 'model')

        expect(result).to eq('claude-3-5-sonnet')
      end

      it 'returns value for symbol key' do
        result = helper.config_value(form, :max_tokens)

        expect(result).to eq(4000)
      end
    end

    context 'with nil prompt' do
      it 'returns default value' do
        result = helper.config_value(nil, :model, 'default')

        expect(result).to eq('default')
      end
    end

    context 'with empty config' do
      let(:prompt) { build(:observ_prompt, config: {}) }

      it 'returns default value' do
        result = helper.config_value(prompt, :model, 'default')

        expect(result).to eq('default')
      end
    end
  end

  describe '#prompt_config_hash (private)' do
    it 'returns parsed config for PromptForm with JSON string' do
      form = Observ::PromptForm.new(config: '{"key": "value"}')

      result = helper.send(:prompt_config_hash, form)

      expect(result).to eq({ 'key' => 'value' })
    end

    it 'returns config hash for Prompt model' do
      prompt = build(:observ_prompt, config: { 'key' => 'value' })

      result = helper.send(:prompt_config_hash, prompt)

      expect(result).to eq({ 'key' => 'value' })
    end

    it 'returns empty hash for nil' do
      result = helper.send(:prompt_config_hash, nil)

      expect(result).to eq({})
    end
  end
end
