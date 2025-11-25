# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Evaluators::JsonStructureEvaluator do
  let(:dataset_item) { create(:observ_dataset_item, expected_output: { name: "Paris", country: "France" }) }
  let(:trace) { create(:observ_trace, output: '{"name": "Paris", "country": "France", "population": 2161000}') }
  let(:run_item) { create(:observ_dataset_run_item, dataset_item: dataset_item, trace: trace) }

  subject(:evaluator) { described_class.new }

  describe "#evaluate" do
    context "with JSON string output" do
      it "returns 1.0 when all expected keys are present" do
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end

      it "returns partial score when some keys are missing" do
        run_item.trace.update!(output: '{"name": "Paris"}')
        run_item.reload
        expect(evaluator.evaluate(run_item)).to eq(0.5)
      end

      it "returns 0.0 when no expected keys are present" do
        run_item.trace.update!(output: '{"other_key": "value"}')
        run_item.reload
        expect(evaluator.evaluate(run_item)).to eq(0.0)
      end
    end

    context "with JSON string output" do
      let(:trace) { create(:observ_trace, output: '{"name": "Paris", "country": "France"}') }

      it "parses JSON and evaluates structure" do
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end
    end

    context "with invalid JSON string output" do
      let(:trace) { create(:observ_trace, output: "not valid json") }

      it "returns 0.0" do
        expect(evaluator.evaluate(run_item)).to eq(0.0)
      end
    end

    context "with explicit required_keys option" do
      let(:evaluator) { described_class.new(required_keys: %w[id name]) }
      let(:trace) { create(:observ_trace, output: '{"id": 1, "name": "Test"}') }

      it "uses provided keys over expected_output" do
        expect(evaluator.evaluate(run_item)).to eq(1.0)
      end
    end

    context "when expected_output is not a hash" do
      let(:dataset_item) { create(:observ_dataset_item, expected_output: "string value") }

      it "returns nil" do
        expect(evaluator.evaluate(run_item)).to be_nil
      end
    end

    context "when output is nil" do
      let(:trace) { create(:observ_trace, output: nil) }

      it "returns 0.0" do
        expect(evaluator.evaluate(run_item)).to eq(0.0)
      end
    end

    context "with mixed key types (string and symbol)" do
      let(:dataset_item) { create(:observ_dataset_item, expected_output: { "name" => "Paris", country: "France" }) }
      let(:trace) { create(:observ_trace, output: '{"name": "Paris", "country": "France"}') }

      it "handles both string and symbol keys" do
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

      expect(score.name).to eq("json_structure")
      expect(score.value).to eq(1.0)
      expect(score.data_type).to eq("numeric")
      expect(score.source).to eq("programmatic")
    end
  end

  describe "default_name" do
    it "returns json_structure" do
      expect(evaluator.name).to eq("json_structure")
    end
  end
end
