# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Scoreable do
  # Test with Session as the concrete class
  let(:scoreable) { create(:observ_session) }

  describe "associations" do
    it "has many scores" do
      expect(scoreable).to respond_to(:scores)
      expect(scoreable.scores).to be_a(ActiveRecord::Associations::CollectionProxy)
    end

    it "destroys scores when scoreable is destroyed" do
      create(:observ_score, scoreable: scoreable)
      expect { scoreable.destroy }.to change(Observ::Score, :count).by(-1)
    end
  end

  describe "#score_for" do
    let!(:accuracy_score) { create(:observ_score, scoreable: scoreable, name: "accuracy", source: :programmatic, value: 0.9) }
    let!(:manual_score) { create(:observ_score, scoreable: scoreable, name: "manual", source: :manual, value: 1.0) }
    let!(:accuracy_manual) { create(:observ_score, scoreable: scoreable, name: "accuracy", source: :manual, value: 0.8) }

    it "returns score by name" do
      # Returns most recent, which is accuracy_manual
      result = scoreable.score_for("accuracy")
      expect(result.name).to eq("accuracy")
    end

    it "returns score by name and source" do
      result = scoreable.score_for("accuracy", source: :programmatic)
      expect(result).to eq(accuracy_score)
    end

    it "returns nil when no matching score exists" do
      expect(scoreable.score_for("nonexistent")).to be_nil
    end

    it "returns the most recent score when multiple exist" do
      newer_score = create(:observ_score, scoreable: scoreable, name: "accuracy", source: :llm_judge, value: 0.7)
      result = scoreable.score_for("accuracy")
      expect(result).to eq(newer_score)
    end
  end

  describe "#scored?" do
    it "returns true when scores exist" do
      create(:observ_score, scoreable: scoreable)
      expect(scoreable.scored?).to be true
    end

    it "returns false when no scores exist" do
      expect(scoreable.scored?).to be false
    end
  end

  describe "#manual_score" do
    it "returns the manual score" do
      manual = create(:observ_score, scoreable: scoreable, name: "manual", source: :manual, value: 1.0)
      create(:observ_score, scoreable: scoreable, name: "accuracy", source: :programmatic, value: 0.9)

      expect(scoreable.manual_score).to eq(manual)
    end

    it "returns nil when no manual score exists" do
      create(:observ_score, scoreable: scoreable, name: "accuracy", source: :programmatic, value: 0.9)
      expect(scoreable.manual_score).to be_nil
    end
  end

  describe "#score_summary" do
    it "returns hash of score names to average values" do
      create(:observ_score, scoreable: scoreable, name: "accuracy", source: :programmatic, value: 0.8)
      create(:observ_score, scoreable: scoreable, name: "accuracy", source: :manual, value: 0.6)
      create(:observ_score, scoreable: scoreable, name: "relevance", source: :programmatic, value: 1.0)

      summary = scoreable.score_summary
      expect(summary["accuracy"]).to eq(0.7)
      expect(summary["relevance"]).to eq(1.0)
    end

    it "returns empty hash when no scores exist" do
      expect(scoreable.score_summary).to eq({})
    end
  end

  describe "inclusion in models" do
    it "is included in Session" do
      session = Observ::Session.new
      expect(session).to respond_to(:scores)
      expect(session).to respond_to(:score_for)
      expect(session).to respond_to(:scored?)
      expect(session).to respond_to(:manual_score)
      expect(session).to respond_to(:score_summary)
    end

    it "is included in Trace" do
      trace = Observ::Trace.new
      expect(trace).to respond_to(:scores)
      expect(trace).to respond_to(:score_for)
      expect(trace).to respond_to(:scored?)
      expect(trace).to respond_to(:manual_score)
      expect(trace).to respond_to(:score_summary)
    end

    it "is included in DatasetRunItem" do
      run_item = Observ::DatasetRunItem.new
      expect(run_item).to respond_to(:scores)
      expect(run_item).to respond_to(:score_for)
      expect(run_item).to respond_to(:scored?)
      expect(run_item).to respond_to(:manual_score)
      expect(run_item).to respond_to(:score_summary)
    end
  end
end
