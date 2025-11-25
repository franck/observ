# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::DatasetRunnerJob, type: :job do
  before(:all) do
    Object.const_set(:TestJobAgent, Class.new do
      def self.name
        "TestJobAgent"
      end

      def call(input)
        { response: "Processed" }
      end
    end)
  end

  after(:all) do
    Object.send(:remove_const, :TestJobAgent) if defined?(TestJobAgent)
  end

  let(:dataset) { create(:observ_dataset, agent_class: "TestJobAgent") }
  let(:dataset_run) { create(:observ_dataset_run, dataset: dataset, status: :pending) }
  let!(:dataset_items) do
    [
      create(:observ_dataset_item, dataset: dataset, input: { text: "Question 1" })
    ]
  end

  before do
    dataset_run.initialize_run_items!
  end

  describe "#perform" do
    it "executes the DatasetRunnerService" do
      expect_any_instance_of(Observ::DatasetRunnerService).to receive(:call)

      described_class.new.perform(dataset_run.id)
    end

    it "finds the dataset run by ID" do
      expect(Observ::DatasetRun).to receive(:find).with(dataset_run.id).and_return(dataset_run)
      allow_any_instance_of(Observ::DatasetRunnerService).to receive(:call)

      described_class.new.perform(dataset_run.id)
    end

    context "when run is already completed" do
      before { dataset_run.update!(status: :completed) }

      it "skips execution" do
        expect(Observ::DatasetRunnerService).not_to receive(:new)

        described_class.new.perform(dataset_run.id)
      end
    end

    context "when run is already failed" do
      before { dataset_run.update!(status: :failed) }

      it "skips execution" do
        expect(Observ::DatasetRunnerService).not_to receive(:new)

        described_class.new.perform(dataset_run.id)
      end
    end

    context "when run is already running" do
      before { dataset_run.update!(status: :running) }

      it "skips execution to avoid duplicate processing" do
        expect(Observ::DatasetRunnerService).not_to receive(:new)

        described_class.new.perform(dataset_run.id)
      end
    end

    context "when run is pending" do
      it "executes the service" do
        expect_any_instance_of(Observ::DatasetRunnerService).to receive(:call)

        described_class.new.perform(dataset_run.id)
      end
    end
  end

  describe "job configuration" do
    it "is queued in the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end

    it "can be enqueued" do
      expect {
        described_class.perform_later(dataset_run.id)
      }.to have_enqueued_job(described_class).with(dataset_run.id)
    end
  end

  describe "error handling" do
    let(:failing_service) do
      instance_double(Observ::DatasetRunnerService)
    end

    before do
      allow(Observ::DatasetRunnerService).to receive(:new).and_return(failing_service)
    end

    context "when service raises an error" do
      before do
        allow(failing_service).to receive(:call).and_raise(StandardError, "Service failed")
      end

      it "allows the error to propagate for retry" do
        expect {
          described_class.new.perform(dataset_run.id)
        }.to raise_error(StandardError, "Service failed")
      end
    end

    context "when run is not found" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          described_class.new.perform(-1)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "retry behavior" do
    it "is configured to retry on StandardError" do
      # Check that the job class has retry_on configuration
      # ActiveJob stores these in rescue_handlers
      handlers = described_class.rescue_handlers.map { |h| h[0] }
      expect(handlers).to include("StandardError")
    end
  end
end
