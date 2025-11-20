require 'rails_helper'

RSpec.describe Observ::PromptConfigValidator do
  describe '#valid?' do
    context 'with blank config' do
      it 'returns true for nil config' do
        validator = described_class.new(nil)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'returns true for empty hash' do
        validator = described_class.new({})
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'with non-hash config' do
      it 'returns false and adds error for string config' do
        validator = described_class.new("not a hash")
        expect(validator.valid?).to be false
        expect(validator.errors).to include("Config must be a Hash")
      end

      it 'returns false and adds error for array config' do
        validator = described_class.new([ 1, 2, 3 ])
        expect(validator.valid?).to be false
        expect(validator.errors).to include("Config must be a Hash")
      end
    end

    context 'with valid config' do
      it 'validates correct temperature value' do
        config = { temperature: 0.7 }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'validates correct max_tokens value' do
        config = { max_tokens: 1000 }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'validates correct top_p value' do
        config = { top_p: 0.9 }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'validates correct frequency_penalty value' do
        config = { frequency_penalty: 0.5 }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'validates correct presence_penalty value' do
        config = { presence_penalty: -0.5 }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'validates correct stop_sequences array' do
        config = { stop_sequences: [ "STOP", "END" ] }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'validates correct model string' do
        config = { model: "gpt-4o" }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'validates correct response_format hash' do
        config = { response_format: { type: "json_object" } }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'validates correct seed integer' do
        config = { seed: 12345 }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'accepts numeric string seed' do
        config = { seed: "12345" }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'validates correct stream boolean' do
        config = { stream: true }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'validates multiple valid keys' do
        config = {
          model: "gpt-4o",
          temperature: 0.8,
          max_tokens: 2000,
          top_p: 0.95,
          stop_sequences: [ "END" ]
        }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'accepts both string and symbol keys' do
        config = { "temperature" => 0.7, :max_tokens => 1000 }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'with invalid type' do
      it 'accepts numeric strings for temperature' do
        config = { temperature: "0.7" }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end

      it 'rejects non-numeric strings for temperature' do
        config = { temperature: "hot" }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("temperature must be a number")
      end

      it 'rejects float for max_tokens (expects integer)' do
        config = { max_tokens: 1000.5 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("max_tokens must be an integer")
      end

      it 'rejects string for top_p (expects float)' do
        config = { top_p: "high" }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("top_p must be a number")
      end

      it 'rejects non-array for stop_sequences' do
        config = { stop_sequences: "STOP" }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("stop_sequences must be an array")
      end

      it 'rejects non-string for model' do
        config = { model: 123 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("model must be a string")
      end

      it 'rejects non-hash for response_format' do
        config = { response_format: "json" }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("response_format must be a hash")
      end

      it 'rejects non-integer for seed' do
        config = { seed: "abc" }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("seed must be an integer")
      end

      it 'rejects non-boolean for stream' do
        config = { stream: "yes" }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("stream must be a boolean")
      end
    end

    context 'with out of range values' do
      it 'rejects temperature below minimum' do
        config = { temperature: -0.1 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("temperature must be between 0.0 and 2.0")
      end

      it 'rejects temperature above maximum' do
        config = { temperature: 2.1 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("temperature must be between 0.0 and 2.0")
      end

      it 'rejects max_tokens below minimum' do
        config = { max_tokens: 0 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("max_tokens must be between 1 and 100000")
      end

      it 'rejects max_tokens above maximum' do
        config = { max_tokens: 100001 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("max_tokens must be between 1 and 100000")
      end

      it 'rejects top_p below minimum' do
        config = { top_p: -0.1 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("top_p must be between 0.0 and 1.0")
      end

      it 'rejects top_p above maximum' do
        config = { top_p: 1.1 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("top_p must be between 0.0 and 1.0")
      end

      it 'rejects frequency_penalty below minimum' do
        config = { frequency_penalty: -2.1 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("frequency_penalty must be between -2.0 and 2.0")
      end

      it 'rejects frequency_penalty above maximum' do
        config = { frequency_penalty: 2.1 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("frequency_penalty must be between -2.0 and 2.0")
      end

      it 'rejects presence_penalty below minimum' do
        config = { presence_penalty: -2.1 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("presence_penalty must be between -2.0 and 2.0")
      end

      it 'rejects presence_penalty above maximum' do
        config = { presence_penalty: 2.1 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("presence_penalty must be between -2.0 and 2.0")
      end
    end

    context 'with invalid array items' do
      it 'rejects non-string items in stop_sequences' do
        config = { stop_sequences: [ "STOP", 123, "END" ] }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("stop_sequences[1] must be a string")
      end

      it 'rejects multiple invalid items in stop_sequences' do
        config = { stop_sequences: [ 123, 456 ] }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("stop_sequences[0] must be a string")
        expect(validator.errors).to include("stop_sequences[1] must be a string")
      end
    end

    context 'with multiple errors' do
      it 'collects all validation errors' do
        config = {
          temperature: 3.0,
          max_tokens: "invalid",
          top_p: -0.5
        }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors.size).to eq(3)
        expect(validator.errors).to include("temperature must be between 0.0 and 2.0")
        expect(validator.errors).to include("max_tokens must be an integer")
        expect(validator.errors).to include("top_p must be between 0.0 and 1.0")
      end
    end

    context 'with unknown keys (when strict mode is disabled)' do
      before do
        allow(Observ.config).to receive(:prompt_config_schema_strict).and_return(false)
      end

      it 'allows unknown keys' do
        config = { unknown_key: "value", temperature: 0.7 }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'with unknown keys (when strict mode is enabled)' do
      before do
        allow(Observ.config).to receive(:prompt_config_schema_strict).and_return(true)
      end

      it 'rejects unknown keys' do
        config = { unknown_key: "value", temperature: 0.7 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors).to include("Unknown configuration keys: unknown_key")
      end

      it 'rejects multiple unknown keys' do
        config = { unknown_key: "value", another_unknown: "value", temperature: 0.7 }
        validator = described_class.new(config)
        expect(validator.valid?).to be false
        expect(validator.errors.first).to match(/Unknown configuration keys:/)
      end
    end

    context 'with edge cases' do
      it 'accepts temperature at minimum boundary' do
        config = { temperature: 0.0 }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
      end

      it 'accepts temperature at maximum boundary' do
        config = { temperature: 2.0 }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
      end

      it 'accepts empty stop_sequences array' do
        config = { stop_sequences: [] }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
      end

      it 'accepts false for stream boolean' do
        config = { stream: false }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
      end

      it 'accepts empty response_format hash' do
        config = { response_format: {} }
        validator = described_class.new(config)
        expect(validator.valid?).to be true
      end
    end
  end
end
