# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Observ::NullPrompt do
  let(:null_prompt) { described_class.new(name: "test-prompt", fallback_text: "Fallback text") }

  describe "Null Object pattern" do
    it "provides the same interface as Prompt" do
      # All these methods should exist and not raise errors
      expect(null_prompt).to respond_to(:name)
      expect(null_prompt).to respond_to(:prompt)
      expect(null_prompt).to respond_to(:version)
      expect(null_prompt).to respond_to(:config)
      expect(null_prompt).to respond_to(:compile)
      expect(null_prompt).to respond_to(:state)
      expect(null_prompt).to respond_to(:draft?)
      expect(null_prompt).to respond_to(:production?)
      expect(null_prompt).to respond_to(:archived?)
      expect(null_prompt).to respond_to(:persisted?)
    end

    it "returns fallback text as prompt" do
      expect(null_prompt.prompt).to eq("Fallback text")
    end

    it "returns nil for version (indicating it's not a real prompt)" do
      expect(null_prompt.version).to be_nil
    end

    it "returns the prompt name" do
      expect(null_prompt.name).to eq("test-prompt")
    end

    it "returns empty config" do
      expect(null_prompt.config).to eq({})
    end

    it "returns 'fallback' as state" do
      expect(null_prompt.state).to eq('fallback')
    end

    it "is not in any real state" do
      expect(null_prompt.draft?).to be false
      expect(null_prompt.production?).to be false
      expect(null_prompt.archived?).to be false
    end

    it "is not persisted" do
      expect(null_prompt.persisted?).to be false
      expect(null_prompt.id).to be_nil
    end
  end

  describe "#compile" do
    it "returns fallback text as-is (no variable compilation)" do
      null_prompt_with_vars = described_class.new(
        name: "test",
        fallback_text: "Hello {{name}}, welcome!"
      )

      result = null_prompt_with_vars.compile(name: "Alice")
      expect(result).to eq("Hello {{name}}, welcome!")
    end

    it "ignores variables" do
      result = null_prompt.compile(foo: "bar", baz: "qux")
      expect(result).to eq("Fallback text")
    end
  end

  describe "usage with PromptManager" do
    it "is returned when prompt not found and fallback provided" do
      result = Observ::PromptManager.fetch(
        name: "non-existent-prompt",
        state: :production,
        fallback: "My fallback"
      )

      expect(result).to be_a(Observ::NullPrompt)
      expect(result.prompt).to eq("My fallback")
      expect(result.version).to be_nil
    end

    it "can be used interchangeably with Prompt in agent code" do
      # Simulate agent code that doesn't need to know if it got a real prompt or NullPrompt
      prompt_or_null = Observ::PromptManager.fetch(
        name: "missing",
        state: :production,
        fallback: "Default behavior"
      )

      # Agent code just calls .prompt regardless of type
      text = prompt_or_null.prompt
      expect(text).to eq("Default behavior")

      # Agent code can check version to see if it's real
      if prompt_or_null.version
        # Real prompt, log version
        Rails.logger.info("Using version #{prompt_or_null.version}")
      else
        # Fallback, log that
        Rails.logger.info("Using fallback")
      end
    end
  end

  describe "logging and debugging" do
    it "provides useful string representation" do
      expect(null_prompt.to_s).to eq("NullPrompt(test-prompt)")
    end

    it "provides useful inspect output" do
      expect(null_prompt.inspect).to include("Observ::NullPrompt")
      expect(null_prompt.inspect).to include("test-prompt")
      expect(null_prompt.inspect).to include("Fallback text")
    end
  end
end
