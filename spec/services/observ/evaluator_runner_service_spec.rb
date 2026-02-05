# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::EvaluatorRunnerService do
  let(:dataset) { create(:observ_dataset) }
  let(:dataset_run) { create(:observ_dataset_run, dataset: dataset, status: :completed) }
  let(:dataset_item) { create(:observ_dataset_item, dataset: dataset, input: { query: "test" }, expected_output: "expected") }
  let(:trace) { create(:observ_trace, output: "expected") }
  let!(:run_item) { create(:observ_dataset_run_item, dataset_run: dataset_run, dataset_item: dataset_item, trace: trace) }

  describe "#call" do
    context "with default evaluators" do
      it "runs exact_match evaluator" do
        service = described_class.new(dataset_run)
        service.call

        expect(run_item.scores.count).to eq(1)
        expect(run_item.scores.first.name).to eq("exact_match")
      end

      it "returns the dataset_run" do
        service = described_class.new(dataset_run)
        expect(service.call).to eq(dataset_run)
      end
    end

    context "with custom evaluator configs" do
      let(:configs) do
        [
          { "type" => "exact_match" },
          { "type" => "contains", "keywords" => ["expected"] }
        ]
      end

      it "runs all configured evaluators" do
        service = described_class.new(dataset_run, evaluator_configs: configs)
        service.call

        expect(run_item.scores.count).to eq(2)
        expect(run_item.scores.pluck(:name)).to contain_exactly("exact_match", "contains")
      end
    end

    context "with json_structure evaluator" do
      let(:json_dataset_item) { create(:observ_dataset_item, dataset: dataset, expected_output: { key: "value" }) }
      let(:json_trace) { create(:observ_trace, output: '{"key": "value", "extra": "data"}') }
      let!(:json_run_item) { create(:observ_dataset_run_item, dataset_run: dataset_run, dataset_item: json_dataset_item, trace: json_trace) }
      let(:configs) { [{ "type" => "json_structure" }] }

      it "runs json_structure evaluator" do
        service = described_class.new(dataset_run, evaluator_configs: configs)
        service.call

        expect(json_run_item.scores.first.name).to eq("json_structure")
        expect(json_run_item.scores.first.value).to eq(1.0)
      end
    end

    context "when run item has no trace" do
      let(:pending_dataset_item) { create(:observ_dataset_item, dataset: dataset) }
      let!(:pending_run_item) do
        create(:observ_dataset_run_item, dataset_run: dataset_run, dataset_item: pending_dataset_item, trace: nil)
      end

      it "skips items without traces" do
        service = described_class.new(dataset_run)
        service.call

        expect(pending_run_item.scores.count).to eq(0)
      end
    end

    context "when run item has an error" do
      let(:failed_dataset_item) { create(:observ_dataset_item, dataset: dataset) }
      let!(:failed_run_item) do
        create(:observ_dataset_run_item, :failed, dataset_run: dataset_run, dataset_item: failed_dataset_item)
      end

      it "skips failed items" do
        service = described_class.new(dataset_run)
        service.call

        expect(failed_run_item.scores.count).to eq(0)
      end
    end

    context "with invalid evaluator type" do
      let(:configs) { [{ "type" => "non_existent" }] }

      it "skips unknown evaluator types without error" do
        service = described_class.new(dataset_run, evaluator_configs: configs)
        expect { service.call }.not_to raise_error
        expect(run_item.scores.count).to eq(0)
      end
    end

    context "when evaluator raises an error" do
      before do
        allow(Observ::Evaluators::ExactMatchEvaluator).to receive(:new).and_raise(StandardError, "Test error")
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).with(/Test error/)

        service = described_class.new(dataset_run)
        expect { service.call }.not_to raise_error
      end
    end

    context "with empty evaluator configs" do
      it "returns early without processing" do
        service = described_class.new(dataset_run, evaluator_configs: [])
        service.call

        expect(run_item.scores.count).to eq(0)
      end
    end

    context "with multiple run items" do
      let(:dataset_item2) { create(:observ_dataset_item, dataset: dataset, expected_output: "other") }
      let(:trace2) { create(:observ_trace, output: "other") }
      let!(:run_item2) { create(:observ_dataset_run_item, dataset_run: dataset_run, dataset_item: dataset_item2, trace: trace2) }

      it "evaluates all succeeded items" do
        service = described_class.new(dataset_run)
        service.call

        expect(run_item.scores.count).to eq(1)
        expect(run_item2.scores.count).to eq(1)
      end
    end
  end

  describe "#evaluate_item" do
    it "runs evaluators for a single item" do
      service = described_class.new(dataset_run)
      service.evaluate_item(run_item)

      expect(run_item.scores.count).to eq(1)
    end
  end

  describe "BUILT_IN_EVALUATORS" do
    it "includes exact_match evaluator" do
      expect(described_class::BUILT_IN_EVALUATORS["exact_match"]).to eq(Observ::Evaluators::ExactMatchEvaluator)
    end

    it "includes contains evaluator" do
      expect(described_class::BUILT_IN_EVALUATORS["contains"]).to eq(Observ::Evaluators::ContainsEvaluator)
    end

    it "includes json_structure evaluator" do
      expect(described_class::BUILT_IN_EVALUATORS["json_structure"]).to eq(Observ::Evaluators::JsonStructureEvaluator)
    end
  end
end
