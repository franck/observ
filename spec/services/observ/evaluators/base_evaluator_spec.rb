# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Evaluators::BaseEvaluator do
  let(:trace) { create(:observ_trace, output: "test output") }
  let(:dataset_item) { create(:observ_dataset_item, expected_output: "expected") }
  let(:run_item) { create(:observ_dataset_run_item, dataset_item: dataset_item, trace: trace) }

  describe "#initialize" do
    it "accepts a custom name" do
      evaluator = described_class.new(name: "custom_evaluator")
      expect(evaluator.name).to eq("custom_evaluator")
    end

    it "derives default name from class name" do
      evaluator = described_class.new
      expect(evaluator.name).to eq("base")
    end

    it "accepts additional options" do
      evaluator = described_class.new(comment: "test comment", threshold: 0.5)
      expect(evaluator.options).to eq({ comment: "test comment", threshold: 0.5 })
    end
  end

  describe "#evaluate" do
    it "raises NotImplementedError" do
      evaluator = described_class.new
      expect { evaluator.evaluate(run_item) }.to raise_error(NotImplementedError)
    end
  end

  describe "#call" do
    let(:concrete_evaluator) do
      Class.new(described_class) do
        def evaluate(_run_item)
          1.0
        end

        def default_name
          "test_evaluator"
        end
      end
    end

    it "returns nil if run_item has no trace" do
      run_item_without_trace = create(:observ_dataset_run_item, dataset_item: dataset_item, trace: nil)
      evaluator = concrete_evaluator.new
      expect(evaluator.call(run_item_without_trace)).to be_nil
    end

    it "returns nil if evaluate returns nil" do
      nil_evaluator = Class.new(described_class) do
        def evaluate(_run_item)
          nil
        end

        def default_name
          "nil_evaluator"
        end
      end

      evaluator = nil_evaluator.new
      expect(evaluator.call(run_item)).to be_nil
    end

    it "creates a score when evaluate returns a value" do
      evaluator = concrete_evaluator.new
      expect { evaluator.call(run_item) }.to change { Observ::Score.count }.by(1)
    end

    it "creates score with correct attributes" do
      evaluator = concrete_evaluator.new(comment: "Test comment")
      score = evaluator.call(run_item)

      expect(score.name).to eq("test_evaluator")
      expect(score.value).to eq(1.0)
      expect(score.source).to eq("programmatic")
      expect(score.data_type).to eq("numeric")
      expect(score.comment).to eq("Test comment")
      expect(score.trace).to eq(trace)
    end

    it "updates existing score on re-run" do
      evaluator = concrete_evaluator.new
      evaluator.call(run_item)

      expect { evaluator.call(run_item) }.not_to change { Observ::Score.count }
    end
  end
end
