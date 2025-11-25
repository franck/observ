# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Evaluators::ExactMatchEvaluator do
  let(:dataset_item) { create(:observ_dataset_item, expected_output: "hello world") }
  let(:trace) { create(:observ_trace, output: "hello world") }
  let(:run_item) { create(:observ_dataset_run_item, dataset_item: dataset_item, trace: trace) }

  subject(:evaluator) { described_class.new }

  describe "#evaluate" do
    context "when output matches expected" do
      it "returns 1.0" do
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end
    end

    context "when output does not match" do
      let(:trace) { create(:observ_trace, output: "different output") }

      it "returns 0.0" do
        expect(evaluator.evaluate(run_item)).to eq(0.0)
      end
    end

    context "when expected_output is blank" do
      let(:dataset_item) { create(:observ_dataset_item, expected_output: nil) }

      it "returns nil" do
        expect(evaluator.evaluate(run_item)).to be_nil
      end
    end

    context "when expected_output is empty string" do
      let(:dataset_item) { create(:observ_dataset_item, expected_output: "") }

      it "returns nil" do
        expect(evaluator.evaluate(run_item)).to be_nil
      end
    end
  end

  describe "#call" do
    it "creates a score record" do
      expect { evaluator.call(run_item) }.to change { Observ::Score.count }.by(1)
    end

    it "creates score with correct attributes" do
      score = evaluator.call(run_item)

      expect(score.name).to eq("exact_match")
      expect(score.value).to eq(1.0)
      expect(score.data_type).to eq("boolean")
      expect(score.source).to eq("programmatic")
    end

    it "updates existing score on re-run" do
      evaluator.call(run_item)
      run_item.trace.update!(output: "different output")
      run_item.reload

      expect { evaluator.call(run_item) }.not_to change { Observ::Score.count }
      expect(run_item.scores.find_by(name: "exact_match").value).to eq(0.0)
    end
  end

  describe "default_name" do
    it "returns exact_match" do
      expect(evaluator.name).to eq("exact_match")
    end
  end

  describe "data_type" do
    it "creates boolean scores" do
      score = evaluator.call(run_item)
      expect(score.data_type).to eq("boolean")
    end
  end
end
