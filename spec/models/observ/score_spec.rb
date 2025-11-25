# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Score, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:dataset_run_item).class_name("Observ::DatasetRunItem") }
    it { is_expected.to belong_to(:trace).class_name("Observ::Trace") }
    it { is_expected.to belong_to(:observation).class_name("Observ::Observation").optional }
  end

  describe "validations" do
    subject { build(:observ_score) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value) }

    it "validates uniqueness of name scoped to dataset_run_item and source" do
      existing = create(:observ_score, name: "accuracy", source: :programmatic)
      duplicate = build(:observ_score,
        dataset_run_item: existing.dataset_run_item,
        trace: existing.trace,
        name: "accuracy",
        source: :programmatic
      )
      expect(duplicate).not_to be_valid
    end

    it "allows same name with different source" do
      existing = create(:observ_score, name: "accuracy", source: :programmatic)
      different_source = build(:observ_score,
        dataset_run_item: existing.dataset_run_item,
        trace: existing.trace,
        name: "accuracy",
        source: :manual
      )
      expect(different_source).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:data_type).with_values(numeric: 0, boolean: 1, categorical: 2) }
    it { is_expected.to define_enum_for(:source).with_values(programmatic: 0, manual: 1, llm_judge: 2) }
  end

  describe "#passed?" do
    it "returns true when value >= 0.5" do
      expect(build(:observ_score, value: 0.5).passed?).to be true
      expect(build(:observ_score, value: 1.0).passed?).to be true
    end

    it "returns false when value < 0.5" do
      expect(build(:observ_score, value: 0.4).passed?).to be false
      expect(build(:observ_score, value: 0.0).passed?).to be false
    end
  end

  describe "#failed?" do
    it "returns true when value < 0.5" do
      expect(build(:observ_score, value: 0.4).failed?).to be true
    end

    it "returns false when value >= 0.5" do
      expect(build(:observ_score, value: 0.5).failed?).to be false
    end
  end

  describe "#display_value" do
    it "returns Pass/Fail for boolean type" do
      expect(build(:observ_score, :boolean, value: 1.0).display_value).to eq("Pass")
      expect(build(:observ_score, :boolean, value: 0.0).display_value).to eq("Fail")
    end

    it "returns rounded value for numeric type" do
      expect(build(:observ_score, value: 0.8567).display_value).to eq("0.86")
    end

    it "returns string_value for categorical type" do
      score = build(:observ_score, data_type: :categorical, string_value: "good", value: 1.0)
      expect(score.display_value).to eq("good")
    end

    it "returns value as string when categorical has no string_value" do
      score = build(:observ_score, data_type: :categorical, string_value: nil, value: 1.0)
      expect(score.display_value).to eq("1.0")
    end
  end

  describe "#badge_class" do
    context "when boolean" do
      it "returns success for passing" do
        expect(build(:observ_score, :boolean, value: 1.0).badge_class).to eq("observ-badge--success")
      end

      it "returns danger for failing" do
        expect(build(:observ_score, :boolean, value: 0.0).badge_class).to eq("observ-badge--danger")
      end
    end

    context "when numeric" do
      it "returns success for >= 0.7" do
        expect(build(:observ_score, value: 0.8).badge_class).to eq("observ-badge--success")
        expect(build(:observ_score, value: 0.7).badge_class).to eq("observ-badge--success")
      end

      it "returns warning for >= 0.4 and < 0.7" do
        expect(build(:observ_score, value: 0.5).badge_class).to eq("observ-badge--warning")
        expect(build(:observ_score, value: 0.4).badge_class).to eq("observ-badge--warning")
      end

      it "returns danger for < 0.4" do
        expect(build(:observ_score, value: 0.3).badge_class).to eq("observ-badge--danger")
        expect(build(:observ_score, value: 0.0).badge_class).to eq("observ-badge--danger")
      end
    end
  end

  describe "delegations" do
    let(:score) { create(:observ_score) }

    it "delegates dataset_run to dataset_run_item" do
      expect(score.dataset_run).to eq(score.dataset_run_item.dataset_run)
    end

    it "delegates dataset_item to dataset_run_item" do
      expect(score.dataset_item).to eq(score.dataset_run_item.dataset_item)
    end
  end
end
