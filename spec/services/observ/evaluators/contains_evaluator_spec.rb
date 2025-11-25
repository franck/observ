# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Evaluators::ContainsEvaluator do
  let(:dataset_item) { create(:observ_dataset_item, expected_output: "Paris") }
  let(:trace) { create(:observ_trace, output: "The capital of France is Paris.") }
  let(:run_item) { create(:observ_dataset_run_item, dataset_item: dataset_item, trace: trace) }

  subject(:evaluator) { described_class.new }

  describe "#evaluate" do
    context "with string expected_output" do
      it "returns 1.0 when output contains the expected string" do
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end

      it "returns 0.0 when output does not contain the expected string" do
        run_item.trace.update!(output: "The capital of France is Lyon.")
        run_item.reload
        expect(evaluator.evaluate(run_item)).to eq(0.0)
      end

      it "is case-insensitive" do
        run_item.trace.update!(output: "The capital of France is PARIS.")
        run_item.reload
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end
    end

    context "with array expected_output (keywords)" do
      let(:dataset_item) { create(:observ_dataset_item, expected_output: %w[Paris France capital]) }

      it "returns 1.0 when all keywords are present" do
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end

      it "returns partial score when some keywords are present" do
        run_item.trace.update!(output: "Paris is a city.")
        run_item.reload
        expect(evaluator.evaluate(run_item)).to eq(1.0 / 3.0)
      end

      it "returns 0.0 when no keywords are present" do
        run_item.trace.update!(output: "London is a city.")
        run_item.reload
        expect(evaluator.evaluate(run_item)).to eq(0.0)
      end
    end

    context "with hash expected_output containing keywords key" do
      let(:dataset_item) { create(:observ_dataset_item, expected_output: { "keywords" => %w[Paris France] }) }

      it "extracts keywords from hash" do
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end
    end

    context "with explicit keywords option" do
      let(:evaluator) { described_class.new(keywords: %w[Paris France]) }

      it "uses provided keywords over expected_output" do
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end
    end

    context "when expected_output is blank" do
      let(:dataset_item) { create(:observ_dataset_item, expected_output: nil) }

      it "returns nil" do
        expect(evaluator.evaluate(run_item)).to be_nil
      end
    end

    context "when actual_output is blank" do
      let(:trace) { create(:observ_trace, output: nil) }

      it "returns 0.0" do
        expect(evaluator.evaluate(run_item)).to eq(0.0)
      end
    end

    context "with hash output" do
      let(:trace) { create(:observ_trace, output: { city: "Paris", country: "France" }) }

      it "converts hash to JSON for searching" do
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end
    end
  end

  describe "#call" do
    it "creates a score record" do
      expect { evaluator.call(run_item) }.to change { Observ::Score.count }.by(1)
    end

    it "creates score with correct attributes" do
      score = evaluator.call(run_item)

      expect(score.name).to eq("contains")
      expect(score.value).to eq(1.0)
      expect(score.data_type).to eq("numeric")
      expect(score.source).to eq("programmatic")
    end
  end

  describe "default_name" do
    it "returns contains" do
      expect(evaluator.name).to eq("contains")
    end
  end
end
