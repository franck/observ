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
      expect(null_prompt).to respond_to(:compile_with_validation)
      expect(null_prompt).to respond_to(:required_variables)
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
    context "with no variables" do
      it "returns the prompt unchanged" do
        expect(null_prompt.compile).to eq("Fallback text")
      end

      it "returns prompt with Mustache syntax unchanged when no variables provided" do
        null_prompt_with_vars = described_class.new(
          name: "test",
          fallback_text: "Hello {{name}}, welcome!"
        )
        expect(null_prompt_with_vars.compile).to eq("Hello {{name}}, welcome!")
      end
    end

    context "with variables" do
      it "interpolates Mustache variables" do
        null_prompt_with_vars = described_class.new(
          name: "test",
          fallback_text: "Hello {{name}}, welcome!"
        )
        result = null_prompt_with_vars.compile(name: "Alice")
        expect(result).to eq("Hello Alice, welcome!")
      end

      it "interpolates multiple variables" do
        null_prompt_with_vars = described_class.new(
          name: "test",
          fallback_text: "Hello {{name}}, your options are: {{options}}"
        )
        result = null_prompt_with_vars.compile(name: "Alice", options: "A, B, C")
        expect(result).to eq("Hello Alice, your options are: A, B, C")
      end
    end

    context "with partial variables" do
      it "interpolates provided variables and leaves missing as empty" do
        null_prompt_with_vars = described_class.new(
          name: "test",
          fallback_text: "Hello {{name}}, your options: {{options}}"
        )
        result = null_prompt_with_vars.compile(name: "Bob")
        expect(result).to eq("Hello Bob, your options: ")
      end
    end

    context "with no template variables in prompt" do
      it "returns the prompt unchanged even with variables provided" do
        result = null_prompt.compile(foo: "bar", baz: "qux")
        expect(result).to eq("Fallback text")
      end
    end
  end

  describe "#compile_with_validation" do
    let(:template_with_vars) { "Hello {{name}}, options: {{options}}" }
    let(:null_prompt_with_vars) { described_class.new(name: "test", fallback_text: template_with_vars) }

    context "with all required variables" do
      it "returns the interpolated prompt" do
        result = null_prompt_with_vars.compile_with_validation(name: "Alice", options: "A, B")
        expect(result).to eq("Hello Alice, options: A, B")
      end
    end

    context "with missing variables" do
      it "raises VariableSubstitutionError" do
        expect {
          null_prompt_with_vars.compile_with_validation(name: "Alice")
        }.to raise_error(Observ::VariableSubstitutionError, /Missing variables: options/)
      end

      it "lists all missing variables" do
        expect {
          null_prompt_with_vars.compile_with_validation({})
        }.to raise_error(Observ::VariableSubstitutionError, /Missing variables: name, options/)
      end
    end

    context "with no variables in template" do
      it "returns the prompt unchanged" do
        simple_prompt = described_class.new(name: "test", fallback_text: "No variables here")
        expect(simple_prompt.compile_with_validation).to eq("No variables here")
      end
    end

    context "with dot notation variables" do
      it "validates root key is present" do
        prompt_with_dot = described_class.new(
          name: "test",
          fallback_text: "Hello {{user.name}}"
        )
        # Providing "user" key should satisfy "user.name" requirement
        result = prompt_with_dot.compile_with_validation(user: { name: "Alice" })
        expect(result).to include("Alice")
      end
    end
  end

  describe "#required_variables" do
    it "extracts variable names from template" do
      null_prompt_with_vars = described_class.new(
        name: "test",
        fallback_text: "Hello {{name}}, options: {{options}}"
      )
      expect(null_prompt_with_vars.required_variables).to contain_exactly("name", "options")
    end

    it "excludes section tags" do
      null_prompt_with_vars = described_class.new(
        name: "test",
        fallback_text: "{{#items}}{{name}}{{/items}}"
      )
      # Section content is stripped, so only top-level vars are extracted
      expect(null_prompt_with_vars.required_variables).to eq([])
    end

    it "returns empty array for template without variables" do
      expect(null_prompt.required_variables).to eq([])
    end

    it "handles dot notation variables" do
      null_prompt_with_dot = described_class.new(
        name: "test",
        fallback_text: "Order for {{customer.name}}: {{total}}"
      )
      expect(null_prompt_with_dot.required_variables).to contain_exactly("customer.name", "total")
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
