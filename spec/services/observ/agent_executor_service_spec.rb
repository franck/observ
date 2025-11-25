# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::AgentExecutorService do
  # Mock RubyLLM chat for testing
  let(:mock_chat) do
    instance_double("RubyLLM::Chat").tap do |chat|
      allow(chat).to receive(:with_instructions).and_return(chat)
      allow(chat).to receive(:with_schema).and_return(chat)
      allow(chat).to receive(:with_params).and_return(chat)
      allow(chat).to receive(:ask).and_return(mock_response)
      # Add callback methods that ChatInstrumenter expects
      allow(chat).to receive(:on_tool_call)
      allow(chat).to receive(:on_tool_result)
      allow(chat).to receive(:on_new_message)
      allow(chat).to receive(:on_end_message)
      allow(chat).to receive(:define_singleton_method)
      allow(chat).to receive(:method).with(:ask).and_return(chat.method(:ask))
    end
  end

  let(:mock_response) do
    double("Response", content: { language_code: "en", confidence: "high" })
  end

  let(:mock_ruby_llm) do
    class_double("RubyLLM").as_stubbed_const
  end

  # Define test agent classes
  before(:all) do
    # Simple agent with just basics
    Object.const_set(:SimpleTestAgent, Class.new do
      def self.name
        "SimpleTestAgent"
      end

      def self.model
        "gpt-4o-mini"
      end

      def self.system_prompt
        "You are a helpful assistant."
      end

      def self.model_parameters
        { temperature: 0.7 }
      end
    end)

    # Agent with schema - define schema class outside
    Object.const_set(:TestSchema, Class.new)

    Object.const_set(:SchemaTestAgent, Class.new do
      def self.name
        "SchemaTestAgent"
      end

      def self.model
        "gpt-4o-mini"
      end

      def self.system_prompt
        "You are a language detector."
      end

      def self.schema
        TestSchema
      end

      def self.model_parameters
        {}
      end
    end)

    # Agent with build_user_prompt
    Object.const_set(:PromptBuilderTestAgent, Class.new do
      def self.name
        "PromptBuilderTestAgent"
      end

      def self.model
        "gpt-4o-mini"
      end

      def self.system_prompt
        "You are an assistant."
      end

      def self.model_parameters
        {}
      end

      def self.build_user_prompt(context)
        "Process this: #{context[:text]} with option: #{context[:option]}"
      end
    end)

    # Invalid agent (missing required methods)
    Object.const_set(:InvalidTestAgent, Class.new do
      def self.name
        "InvalidTestAgent"
      end
    end)
  end

  after(:all) do
    Object.send(:remove_const, :SimpleTestAgent) if defined?(SimpleTestAgent)
    Object.send(:remove_const, :SchemaTestAgent) if defined?(SchemaTestAgent)
    Object.send(:remove_const, :TestSchema) if defined?(TestSchema)
    Object.send(:remove_const, :PromptBuilderTestAgent) if defined?(PromptBuilderTestAgent)
    Object.send(:remove_const, :InvalidTestAgent) if defined?(InvalidTestAgent)
  end

  before do
    allow(mock_ruby_llm).to receive(:chat).and_return(mock_chat)
  end

  describe "#initialize" do
    it "accepts an agent class" do
      executor = described_class.new(SimpleTestAgent)
      expect(executor.agent_class).to eq(SimpleTestAgent)
    end

    it "accepts an observability session" do
      session = create(:observ_session)
      executor = described_class.new(SimpleTestAgent, observability_session: session)
      expect(executor.observability_session).to eq(session)
    end

    it "raises ArgumentError for invalid agent class" do
      expect {
        described_class.new(InvalidTestAgent)
      }.to raise_error(ArgumentError, /must respond to :model and :system_prompt/)
    end

    context "when RubyLLM is not defined" do
      before do
        hide_const("RubyLLM")
      end

      it "raises RubyLLMNotAvailableError" do
        expect {
          described_class.new(SimpleTestAgent)
        }.to raise_error(Observ::AgentExecutorService::RubyLLMNotAvailableError)
      end
    end
  end

  describe "#call" do
    subject(:executor) { described_class.new(SimpleTestAgent) }

    context "with string input" do
      it "creates a chat with the agent's model" do
        expect(mock_ruby_llm).to receive(:chat).with(model: "gpt-4o-mini").and_return(mock_chat)

        executor.call("Hello")
      end

      it "applies system prompt" do
        expect(mock_chat).to receive(:with_instructions).with("You are a helpful assistant.")

        executor.call("Hello")
      end

      it "applies model parameters" do
        expect(mock_chat).to receive(:with_params).with(temperature: 0.7)

        executor.call("Hello")
      end

      it "calls ask with the input" do
        expect(mock_chat).to receive(:ask).with("Hello")

        executor.call("Hello")
      end

      it "returns the response content with symbolized keys" do
        result = executor.call("Hello")

        expect(result).to eq({ language_code: "en", confidence: "high" })
      end
    end

    context "with hash input" do
      it "extracts text from :text key" do
        expect(mock_chat).to receive(:ask).with("Hello from hash")

        executor.call(text: "Hello from hash")
      end

      it "extracts text from 'text' string key" do
        expect(mock_chat).to receive(:ask).with("Hello string key")

        executor.call("text" => "Hello string key")
      end

      it "extracts text from :content key" do
        expect(mock_chat).to receive(:ask).with("Content text")

        executor.call(content: "Content text")
      end

      it "extracts text from :input key" do
        expect(mock_chat).to receive(:ask).with("Input text")

        executor.call(input: "Input text")
      end

      it "falls back to JSON for unknown hash structure" do
        input = { custom_field: "value" }
        expect(mock_chat).to receive(:ask).with(input.to_json)

        executor.call(input)
      end
    end

    context "with agent that has schema" do
      subject(:executor) { described_class.new(SchemaTestAgent) }

      it "applies the schema" do
        expect(mock_chat).to receive(:with_schema).with(SchemaTestAgent.schema)

        executor.call("Hello")
      end
    end

    context "with agent that implements build_user_prompt" do
      subject(:executor) { described_class.new(PromptBuilderTestAgent) }

      it "uses build_user_prompt with hash input" do
        expect(mock_chat).to receive(:ask).with("Process this: Hello with option: fast")

        executor.call(text: "Hello", option: "fast")
      end

      it "wraps string input in hash for build_user_prompt" do
        expect(mock_chat).to receive(:ask).with("Process this: Hello with option: ")

        executor.call("Hello")
      end
    end

    context "with observability session" do
      let(:session) { create(:observ_session) }
      subject(:executor) { described_class.new(SimpleTestAgent, observability_session: session) }

      it "instruments the chat" do
        expect(Observ::ChatInstrumenter).to receive(:new)
          .with(session, mock_chat, hash_including(context: hash_including(service: "agent_executor")))
          .and_call_original

        executor.call("Hello")
      end
    end

    context "when chat.ask raises an error" do
      before do
        allow(mock_chat).to receive(:ask).and_raise(StandardError, "API error")
      end

      it "raises ExecutionError with details" do
        expect {
          executor.call("Hello")
        }.to raise_error(Observ::AgentExecutorService::ExecutionError, /Agent execution failed: API error/)
      end
    end

    context "response normalization" do
      it "symbolizes string keys in hash response" do
        allow(mock_response).to receive(:content).and_return({ "language" => "en", "score" => 0.9 })

        result = executor.call("Hello")

        expect(result).to eq({ language: "en", score: 0.9 })
      end

      it "handles string response" do
        allow(mock_response).to receive(:content).and_return("Plain text response")

        result = executor.call("Hello")

        expect(result).to eq("Plain text response")
      end

      it "deep symbolizes nested hashes" do
        allow(mock_response).to receive(:content).and_return({
          "outer" => { "inner" => "value" }
        })

        result = executor.call("Hello")

        expect(result).to eq({ outer: { inner: "value" } })
      end
    end
  end

  describe "context passing" do
    let(:session) { create(:observ_session) }

    it "merges custom context with default context" do
      custom_context = { dataset_id: 123, run_id: 456 }

      expect(Observ::ChatInstrumenter).to receive(:new)
        .with(
          session,
          mock_chat,
          context: hash_including(
            service: "agent_executor",
            agent_class: SimpleTestAgent,
            dataset_id: 123,
            run_id: 456
          )
        )
        .and_call_original

      executor = described_class.new(
        SimpleTestAgent,
        observability_session: session,
        context: custom_context
      )
      executor.call("Hello")
    end
  end
end
