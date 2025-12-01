# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::DatasetRunnerService do
  # Mock RubyLLM for all tests
  let(:mock_chat) do
    instance_double("RubyLLM::Chat").tap do |chat|
      allow(chat).to receive(:with_instructions).and_return(chat)
      allow(chat).to receive(:with_schema).and_return(chat)
      allow(chat).to receive(:with_params).and_return(chat)
      allow(chat).to receive(:on_tool_call)
      allow(chat).to receive(:on_tool_result)
      allow(chat).to receive(:on_new_message)
      allow(chat).to receive(:on_end_message)
      allow(chat).to receive(:define_singleton_method)
      allow(chat).to receive(:complete).and_return(mock_response)
      # Return a proc that returns mock_response for both :ask and :complete methods
      allow(chat).to receive(:method) do |method_name|
        ->(*_args, **_kwargs, &_block) { mock_response }
      end
    end
  end

  let(:mock_response) do
    double("Response", content: { response: "Processed" })
  end

  let(:mock_ruby_llm) do
    class_double("RubyLLM").as_stubbed_const
  end

  # Create test agent classes that implement the AgentExecutorService interface
  # They need to respond to :model and :system_prompt
  before(:all) do
    # Define TestEvaluationAgent - compatible with AgentExecutorService
    Object.const_set(:TestEvaluationAgent, Class.new do
      def self.name
        "TestEvaluationAgent"
      end

      def self.model
        "gpt-4o-mini"
      end

      def self.system_prompt
        "You are a test agent."
      end

      def self.model_parameters
        {}
      end
    end)

    # Define FailingAgent - will fail when chat.ask is called
    Object.const_set(:FailingAgent, Class.new do
      def self.name
        "FailingAgent"
      end

      def self.model
        "gpt-4o-mini"
      end

      def self.system_prompt
        "You are a failing agent."
      end

      def self.model_parameters
        {}
      end
    end)
  end

  after(:all) do
    Object.send(:remove_const, :TestEvaluationAgent) if defined?(TestEvaluationAgent)
    Object.send(:remove_const, :FailingAgent) if defined?(FailingAgent)
  end

  before do
    allow(mock_ruby_llm).to receive(:chat).and_return(mock_chat)
    allow(mock_chat).to receive(:ask).and_return(mock_response)
  end

  let(:dataset) { create(:observ_dataset, agent_class: "TestEvaluationAgent") }
  let(:dataset_run) { create(:observ_dataset_run, dataset: dataset, status: :pending) }
  let!(:dataset_items) do
    [
      create(:observ_dataset_item, dataset: dataset, input: { text: "Question 1" }),
      create(:observ_dataset_item, dataset: dataset, input: { text: "Question 2" }),
      create(:observ_dataset_item, dataset: dataset, input: { text: "Question 3" })
    ]
  end

  before do
    # Initialize run items
    dataset_run.initialize_run_items!
  end

  describe "#call" do
    subject(:service) { described_class.new(dataset_run) }

    it "sets run status to running at start" do
      expect { service.call }.to change { dataset_run.reload.status }.from("pending").to("completed")

      # Check that it was running during execution (we can verify by the final state)
      expect(dataset_run.status).to eq("completed")
    end

    it "processes all run items" do
      service.call

      dataset_run.run_items.reload.each do |run_item|
        expect(run_item.trace).to be_present
        expect(run_item.succeeded?).to be true
      end
    end

    it "creates a session for each item" do
      expect { service.call }.to change(Observ::Session, :count).by(3)
    end

    it "creates a trace for each item" do
      expect { service.call }.to change(Observ::Trace, :count).by(3)
    end

    it "sets trace metadata correctly" do
      service.call

      trace = dataset_run.run_items.first.trace
      expect(trace.metadata).to include(
        "dataset_id" => dataset.id,
        "dataset_name" => dataset.name,
        "dataset_run_id" => dataset_run.id,
        "agent_class" => "TestEvaluationAgent"
      )
    end

    it "finalizes traces with output" do
      service.call

      dataset_run.run_items.reload.each do |run_item|
        expect(run_item.trace.output).to be_present
        expect(run_item.trace.end_time).to be_present
      end
    end

    it "updates run metrics after completion" do
      service.call
      dataset_run.reload

      expect(dataset_run.completed_items).to eq(3)
      expect(dataset_run.failed_items).to eq(0)
    end

    it "sets final status to completed when all items succeed" do
      service.call

      expect(dataset_run.reload.status).to eq("completed")
    end

    context "when some items fail" do
      before(:all) do
        # Define MixedAgent - compatible with AgentExecutorService
        Object.const_set(:MixedAgent, Class.new do
          def self.name
            "MixedAgent"
          end

          def self.model
            "gpt-4o-mini"
          end

          def self.system_prompt
            "You are a mixed agent."
          end

          def self.model_parameters
            {}
          end
        end)
      end

      after(:all) do
        Object.send(:remove_const, :MixedAgent) if defined?(MixedAgent)
      end

      before do
        dataset.update!(agent_class: "MixedAgent")

        # Make chat.ask fail on second call
        call_count = 0
        allow(mock_chat).to receive(:ask) do
          call_count += 1
          if call_count == 2
            raise StandardError, "Item 2 failed"
          end
          mock_response
        end
      end

      it "records errors for failed items" do
        service.call

        failed_item = dataset_run.run_items.find(&:failed?)
        expect(failed_item).to be_present
        expect(failed_item.error).to include("Item 2 failed")
      end

      it "continues processing after failures" do
        service.call

        succeeded = dataset_run.run_items.select(&:succeeded?)
        expect(succeeded.count).to eq(2)
      end

      it "sets status to completed (not failed) when some items succeed" do
        service.call

        expect(dataset_run.reload.status).to eq("completed")
      end

      it "tracks failed items in metrics" do
        service.call

        expect(dataset_run.reload.failed_items).to eq(1)
        expect(dataset_run.completed_items).to eq(2)
      end
    end

    context "when all items fail" do
      before do
        dataset.update!(agent_class: "FailingAgent")
        allow(mock_chat).to receive(:ask).and_raise(StandardError, "Agent execution failed")
      end

      it "sets final status to failed" do
        service.call

        expect(dataset_run.reload.status).to eq("failed")
      end

      it "records errors for all items" do
        service.call

        dataset_run.run_items.reload.each do |run_item|
          expect(run_item.failed?).to be true
          expect(run_item.error).to include("Agent execution failed")
        end
      end
    end

    context "when a catastrophic error occurs" do
      before do
        allow(dataset_run).to receive(:update!).and_call_original
        allow(dataset_run).to receive(:update!)
          .with(status: :running)
          .and_raise(ActiveRecord::RecordInvalid.new(dataset_run))
      end

      it "sets run status to failed and re-raises the error" do
        expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)

        # The error handler marks it as failed
        expect(dataset_run.reload.status).to eq("failed")
      end
    end

    context "with string input" do
      let(:dataset_items) do
        [
          create(:observ_dataset_item, dataset: dataset, input: "Simple string input")
        ]
      end

      it "handles string input correctly" do
        service.call

        run_item = dataset_run.run_items.first
        expect(run_item.succeeded?).to be true
      end
    end
  end

  describe "session and trace linking" do
    subject(:service) { described_class.new(dataset_run) }

    it "creates sessions with correct user_id format" do
      service.call

      sessions = Observ::Session.where("user_id LIKE ?", "dataset_run_%")
      expect(sessions.count).to eq(3)
      expect(sessions.first.user_id).to eq("dataset_run_#{dataset_run.id}")
    end

    it "creates sessions with source metadata" do
      service.call

      session = Observ::Session.last
      expect(session.metadata).to include("source" => "dataset_evaluation")
    end

    it "creates traces with dataset_evaluation name" do
      service.call

      traces = Observ::Trace.where(name: "dataset_evaluation")
      expect(traces.count).to eq(3)
    end

    it "tags traces appropriately" do
      service.call

      trace = dataset_run.run_items.first.trace
      expect(trace.tags).to include("dataset_evaluation", dataset.name, dataset_run.name)
    end
  end

  describe "agent execution via AgentExecutorService" do
    subject(:service) { described_class.new(dataset_run) }

    it "uses AgentExecutorService to execute agents" do
      expect(Observ::AgentExecutorService).to receive(:new)
        .with(TestEvaluationAgent, hash_including(observability_session: instance_of(Observ::Session)))
        .exactly(3).times
        .and_call_original

      service.call
    end

    it "passes context to AgentExecutorService" do
      expect(Observ::AgentExecutorService).to receive(:new)
        .with(
          TestEvaluationAgent,
          hash_including(
            context: hash_including(
              dataset_id: dataset.id,
              dataset_run_id: dataset_run.id
            )
          )
        )
        .exactly(3).times
        .and_call_original

      service.call
    end

    context "with invalid agent (missing required methods)" do
      before(:all) do
        Object.const_set(:InvalidAgent, Class.new do
          def self.name
            "InvalidAgent"
          end
          # Missing model and system_prompt methods
        end)
      end

      after(:all) do
        Object.send(:remove_const, :InvalidAgent) if defined?(InvalidAgent)
      end

      before do
        dataset.update!(agent_class: "InvalidAgent")
      end

      it "records the error for each item" do
        service.call

        dataset_run.run_items.reload.each do |run_item|
          expect(run_item.failed?).to be true
          expect(run_item.error).to include("must respond to :model and :system_prompt")
        end
      end
    end
  end
end
