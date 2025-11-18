require 'rails_helper'

RSpec.describe Observ::Prompt, type: :model do
  before do
    # Clear cache before each test for predictability
    Rails.cache.clear
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:prompt) }
    it { should validate_presence_of(:version) }
    it { should validate_presence_of(:state) }

    it "validates version is a positive integer" do
      prompt = build(:observ_prompt, version: -1)
      expect(prompt).not_to be_valid
      expect(prompt.errors[:version]).to include("must be greater than 0")
    end

    it "validates state is in allowed values" do
      prompt = build(:observ_prompt, state: 'invalid')
      expect(prompt).not_to be_valid
      expect(prompt.errors[:state]).to include("is not included in the list")
    end

    describe "only one production per name" do
      it "allows only one production version per prompt name" do
        create(:observ_prompt, :production, name: "test-prompt")
        duplicate = build(:observ_prompt, state: :production, name: "test-prompt", version: 2)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:state]).to include("Only one production version allowed per prompt name")
      end

      it "allows multiple draft versions with same name" do
        create(:observ_prompt, :draft, name: "test-prompt", version: 1)
        duplicate = create(:observ_prompt, :draft, name: "test-prompt", version: 2)

        expect(duplicate).to be_valid
      end
    end
  end

  describe "AASM state machine" do
    let(:prompt) { create(:observ_prompt, :draft) }

    describe "initial state" do
      it "starts as draft" do
        new_prompt = Observ::Prompt.new(name: "test", prompt: "text", version: 1)
        expect(new_prompt.state).to eq("draft")
      end
    end

    describe "#promote" do
      it "transitions from draft to production" do
        expect { prompt.promote! }.to change { prompt.state }.from("draft").to("production")
      end

      it "demotes existing production version to archived" do
        existing_production = create(:observ_prompt, :production, name: "same-name", version: 1)
        new_draft = create(:observ_prompt, :draft, name: "same-name", version: 2)

        new_draft.promote!

        expect(new_draft.reload.state).to eq("production")
        expect(existing_production.reload.state).to eq("archived")
      end
    end

    describe "#demote" do
      let(:production_prompt) { create(:observ_prompt, :production) }

      it "transitions from production to archived" do
        expect { production_prompt.demote! }.to change { production_prompt.state }
          .from("production").to("archived")
      end
    end

    describe "#restore" do
      let(:archived_prompt) { create(:observ_prompt, :archived) }

      it "transitions from archived to production" do
        expect { archived_prompt.restore! }.to change { archived_prompt.state }
          .from("archived").to("production")
      end

      it "demotes existing production version" do
        existing_production = create(:observ_prompt, :production, name: "same-name", version: 1)
        archived = create(:observ_prompt, :archived, name: "same-name", version: 2)

        archived.restore!

        expect(archived.reload.state).to eq("production")
        expect(existing_production.reload.state).to eq("archived")
      end
    end
  end

  describe ".fetch" do
    let!(:draft) { create(:observ_prompt, :draft, name: "test-prompt", version: 1) }
    let!(:production) { create(:observ_prompt, :production, name: "test-prompt", version: 2) }
    let!(:archived) { create(:observ_prompt, :archived, name: "test-prompt", version: 3) }

    it "fetches production version by default" do
      result = described_class.fetch(name: "test-prompt")
      expect(result.id).to eq(production.id)
      expect(result.state).to eq("production")
    end

    it "fetches specific version when provided" do
      result = described_class.fetch(name: "test-prompt", version: 1)
      expect(result.id).to eq(draft.id)
    end

    it "fetches by state" do
      result = described_class.fetch(name: "test-prompt", state: :draft)
      expect(result.id).to eq(draft.id)
    end

    it "raises error when prompt not found and no fallback" do
      expect {
        described_class.fetch(name: "nonexistent")
      }.to raise_error(Observ::PromptNotFoundError, "Prompt 'nonexistent' not found")
    end

    it "returns fallback when prompt not found" do
      result = described_class.fetch(name: "nonexistent", fallback: "default text")
      expect(result).to eq("default text")
    end
  end

  describe ".create_version" do
    it "creates first version as 1" do
      prompt = described_class.create_version(
        name: "new-prompt",
        prompt: "Hello {{name}}",
        config: { model: "gpt-4o" }
      )

      expect(prompt.version).to eq(1)
      expect(prompt.state).to eq("draft")
    end

    it "auto-increments version number" do
      create(:observ_prompt, name: "test", version: 1)
      create(:observ_prompt, name: "test", version: 2)

      new_prompt = described_class.create_version(name: "test", prompt: "text")
      expect(new_prompt.version).to eq(3)
    end

    it "promotes to production if requested" do
      prompt = described_class.create_version(
        name: "new-prompt",
        prompt: "text",
        promote_to_production: true
      )

      expect(prompt.state).to eq("production")
    end
  end

  describe "#compile" do
    let(:prompt) { create(:observ_prompt, :with_variables) }

    it "substitutes variables" do
      result = prompt.compile(name: "Alice", age: 30, job: "engineer")
      expect(result).to eq("Hello Alice, you are 30 years old and work as a engineer.")
    end

    it "leaves unmatched variables as-is" do
      result = prompt.compile(name: "Bob")
      expect(result).to include("{{age}}")
      expect(result).to include("{{job}}")
    end
  end

  describe "#compile_with_validation" do
    let(:prompt) { create(:observ_prompt, :with_variables) }

    it "compiles successfully with all variables" do
      result = prompt.compile_with_validation(name: "Alice", age: 30, job: "engineer")
      expect(result).to eq("Hello Alice, you are 30 years old and work as a engineer.")
    end

    it "raises error for missing variables" do
      expect {
        prompt.compile_with_validation(name: "Bob")
      }.to raise_error(Observ::VariableSubstitutionError, /Missing variables: age, job/)
    end
  end

  describe "immutability" do
    describe "#editable?" do
      it "returns true for draft" do
        draft = create(:observ_prompt, :draft)
        expect(draft.editable?).to be true
      end

      it "returns false for production" do
        production = create(:observ_prompt, :production)
        expect(production.editable?).to be false
      end

      it "returns false for archived" do
        archived = create(:observ_prompt, :archived)
        expect(archived.editable?).to be false
      end
    end

    describe "updating prompts" do
      it "allows editing draft prompts" do
        draft = create(:observ_prompt, :draft)
        expect { draft.update!(prompt: "New text") }.not_to raise_error
      end

      it "prevents editing production prompts" do
        production = create(:observ_prompt, :production)
        expect {
          production.update!(prompt: "New text")
        }.to raise_error(ActiveRecord::RecordInvalid, /Cannot edit production prompt/)
      end

      it "prevents editing archived prompts" do
        archived = create(:observ_prompt, :archived)
        expect {
          archived.update!(prompt: "New text")
        }.to raise_error(ActiveRecord::RecordInvalid, /Cannot edit archived prompt/)
      end

      it "allows state transitions on immutable prompts" do
        production = create(:observ_prompt, :production)
        expect { production.demote! }.not_to raise_error
      end
    end
  end

  describe "#clone_to_draft" do
    let(:production) { create(:observ_prompt, :production, name: "test", version: 1) }

    it "creates new draft version with same content" do
      clone = production.clone_to_draft

      expect(clone.name).to eq(production.name)
      expect(clone.prompt).to eq(production.prompt)
      expect(clone.config).to eq(production.config)
      expect(clone.state).to eq("draft")
      expect(clone.version).to eq(2)
    end
  end

  describe "version navigation" do
    let!(:v1) { create(:observ_prompt, name: "test", version: 1) }
    let!(:v2) { create(:observ_prompt, name: "test", version: 2) }
    let!(:v3) { create(:observ_prompt, name: "test", version: 3) }

    describe "#previous_version" do
      it "returns previous version" do
        expect(v2.previous_version.id).to eq(v1.id)
      end

      it "returns nil for first version" do
        expect(v1.previous_version).to be_nil
      end
    end

    describe "#next_version" do
      it "returns next version" do
        expect(v2.next_version.id).to eq(v3.id)
      end

      it "returns nil for latest version" do
        expect(v3.next_version).to be_nil
      end
    end

    describe "#latest_version" do
      it "returns latest version for all versions" do
        expect(v1.latest_version.id).to eq(v3.id)
        expect(v2.latest_version.id).to eq(v3.id)
        expect(v3.latest_version.id).to eq(v3.id)
      end
    end
  end

  describe "export" do
    let(:prompt) { create(:observ_prompt) }

    describe "#to_json_export" do
      it "exports without timestamps and id" do
        json = prompt.to_json_export
        expect(json).to include("name", "prompt", "version", "state", "config")
        expect(json).not_to include("id", "created_at", "updated_at")
      end
    end

    describe "#to_yaml_export" do
      it "exports as YAML" do
        yaml = prompt.to_yaml_export
        expect(yaml).to be_a(String)
        expect(yaml).to include("name:")
        expect(yaml).to include("version:")
      end
    end
  end

  describe "cache invalidation" do
    it "invalidates cache after updating prompt content" do
      draft = create(:observ_prompt, :draft, name: 'test-draft')

      expect(Observ::PromptManager).to receive(:invalidate_cache).with(name: 'test-draft')
      draft.update(prompt: 'Updated prompt content')
    end

    it "invalidates cache after updating config" do
      draft = create(:observ_prompt, :draft, name: 'test-config')

      expect(Observ::PromptManager).to receive(:invalidate_cache).with(name: 'test-config')
      draft.update(config: { model: 'gpt-4o' })
    end

    it "invalidates cache after state transition" do
      draft = create(:observ_prompt, :draft, name: 'test-draft')

      # State transitions trigger invalidation at least once (could be from transition + save)
      expect(Observ::PromptManager).to receive(:invalidate_cache).with(name: 'test-draft').at_least(:once)
      draft.promote!
    end

    it "invalidates cache after destroy" do
      production = create(:observ_prompt, :production, name: 'test')

      expect(Observ::PromptManager).to receive(:invalidate_cache).with(name: 'test')
      production.destroy
    end

    it "generates correct cache key (legacy method)" do
      cache_key = described_class.cache_key_for(name: "test", version: nil, state: :production)
      expect(cache_key).to eq("observ:prompt:test:production")

      cache_key_with_version = described_class.cache_key_for(name: "test", version: 1, state: :production)
      expect(cache_key_with_version).to eq("observ:prompt:test:1")
    end

    it "clears cache for all states (legacy method)" do
      expect(Rails.cache).to receive(:delete).with("observ:prompt:test:draft")
      expect(Rails.cache).to receive(:delete).with("observ:prompt:test:production")
      expect(Rails.cache).to receive(:delete).with("observ:prompt:test:archived")

      described_class.clear_cache(name: "test")
    end
  end

  describe "config normalization" do
    it "converts config string to hash before save" do
      prompt = build(:observ_prompt, config: '{"model": "gpt-4o", "temperature": 0.7}')
      prompt.save!

      expect(prompt.config).to be_a(Hash)
      expect(prompt.config["model"]).to eq("gpt-4o")
      expect(prompt.config["temperature"]).to eq(0.7)
    end

    it "handles invalid JSON by defaulting to empty hash" do
      prompt = build(:observ_prompt, config: "{invalid json}")
      prompt.save!

      expect(prompt.config).to eq({})
    end

    it "preserves hash config unchanged" do
      original_config = { "model" => "gpt-4o", "temperature" => 0.5 }
      prompt = build(:observ_prompt, config: original_config)
      prompt.save!

      expect(prompt.config).to eq(original_config)
    end

    it "handles nil config" do
      prompt = build(:observ_prompt, config: nil)
      prompt.save!

      expect(prompt.config).to be_nil
    end

    it "converts non-hash, non-string config to empty hash" do
      prompt = build(:observ_prompt)
      prompt.config = 123  # Simulate edge case
      prompt.save!

      expect(prompt.config).to eq({})
    end

    it "normalizes config on update" do
      prompt = create(:observ_prompt, :draft, config: { "model" => "gpt-3.5" })

      # Simulate what happens when form submits JSON string
      prompt.update!(config: '{"model": "gpt-4o", "temperature": 0.9}')

      expect(prompt.config).to be_a(Hash)
      expect(prompt.config["model"]).to eq("gpt-4o")
      expect(prompt.config["temperature"]).to eq(0.9)
    end
  end

  describe "config validation" do
    context "with valid config" do
      it "accepts valid temperature" do
        prompt = build(:observ_prompt, config: { temperature: 0.7 })
        expect(prompt).to be_valid
      end

      it "accepts valid max_tokens" do
        prompt = build(:observ_prompt, config: { max_tokens: 1000 })
        expect(prompt).to be_valid
      end

      it "accepts valid top_p" do
        prompt = build(:observ_prompt, config: { top_p: 0.9 })
        expect(prompt).to be_valid
      end

      it "accepts valid frequency_penalty" do
        prompt = build(:observ_prompt, config: { frequency_penalty: 0.5 })
        expect(prompt).to be_valid
      end

      it "accepts valid presence_penalty" do
        prompt = build(:observ_prompt, config: { presence_penalty: -0.5 })
        expect(prompt).to be_valid
      end

      it "accepts valid stop_sequences" do
        prompt = build(:observ_prompt, config: { stop_sequences: [ "STOP", "END" ] })
        expect(prompt).to be_valid
      end

      it "accepts valid model" do
        prompt = build(:observ_prompt, config: { model: "gpt-4o" })
        expect(prompt).to be_valid
      end

      it "accepts multiple valid config keys" do
        prompt = build(:observ_prompt, config: {
          model: "gpt-4o",
          temperature: 0.8,
          max_tokens: 2000,
          top_p: 0.95
        })
        expect(prompt).to be_valid
      end

      it "accepts blank config" do
        prompt = build(:observ_prompt, config: {})
        expect(prompt).to be_valid
      end

      it "accepts nil config" do
        prompt = build(:observ_prompt, config: nil)
        expect(prompt).to be_valid
      end
    end

    context "with invalid config" do
      it "rejects temperature out of range" do
        prompt = build(:observ_prompt, config: { temperature: 3.0 })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("temperature must be between 0.0 and 2.0")
      end

      it "rejects negative temperature" do
        prompt = build(:observ_prompt, config: { temperature: -0.5 })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("temperature must be between 0.0 and 2.0")
      end

      it "rejects max_tokens out of range" do
        prompt = build(:observ_prompt, config: { max_tokens: 0 })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("max_tokens must be between 1 and 100000")
      end

      it "rejects max_tokens above maximum" do
        prompt = build(:observ_prompt, config: { max_tokens: 100001 })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("max_tokens must be between 1 and 100000")
      end

      it "rejects top_p out of range" do
        prompt = build(:observ_prompt, config: { top_p: 1.5 })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("top_p must be between 0.0 and 1.0")
      end

      it "rejects frequency_penalty out of range" do
        prompt = build(:observ_prompt, config: { frequency_penalty: 3.0 })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("frequency_penalty must be between -2.0 and 2.0")
      end

      it "rejects presence_penalty out of range" do
        prompt = build(:observ_prompt, config: { presence_penalty: -3.0 })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("presence_penalty must be between -2.0 and 2.0")
      end

      it "rejects invalid temperature type" do
        prompt = build(:observ_prompt, config: { temperature: "high" })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("temperature must be a number")
      end

      it "rejects invalid max_tokens type" do
        prompt = build(:observ_prompt, config: { max_tokens: "1000" })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("max_tokens must be an integer")
      end

      it "rejects invalid stop_sequences type" do
        prompt = build(:observ_prompt, config: { stop_sequences: "STOP" })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("stop_sequences must be an array")
      end

      it "rejects invalid array items in stop_sequences" do
        prompt = build(:observ_prompt, config: { stop_sequences: [ "STOP", 123 ] })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("stop_sequences[1] must be a string")
      end

      it "rejects invalid model type" do
        prompt = build(:observ_prompt, config: { model: 123 })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("model must be a string")
      end

      it "collects multiple validation errors" do
        prompt = build(:observ_prompt, config: {
          temperature: 3.0,
          max_tokens: "invalid",
          top_p: -0.5
        })
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config].size).to eq(3)
      end
    end

    context "with config normalization and validation" do
      it "normalizes and validates config before save" do
        prompt = build(:observ_prompt, config: '{"temperature": 0.7}')
        expect(prompt).to be_valid
        prompt.save!
        expect(prompt.config).to be_a(Hash)
        expect(prompt.config["temperature"]).to eq(0.7)
      end

      it "normalizes invalid JSON to empty hash (which is valid)" do
        prompt = build(:observ_prompt, config: "{invalid json}")
        expect(prompt).to be_valid
        prompt.save!
        expect(prompt.config).to eq({})
      end

      it "rejects normalized config with invalid values" do
        prompt = build(:observ_prompt, config: '{"temperature": 3.0}')
        expect(prompt).not_to be_valid
        expect(prompt.errors[:config]).to include("temperature must be between 0.0 and 2.0")
      end
    end

    context "backward compatibility" do
      it "allows prompts with no config to be valid" do
        prompt = build(:observ_prompt, config: nil)
        expect(prompt).to be_valid
      end

      it "allows prompts with empty config to be valid" do
        prompt = build(:observ_prompt, config: {})
        expect(prompt).to be_valid
      end
    end
  end
end
