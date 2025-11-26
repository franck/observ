# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Score, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:scoreable) }
    it { is_expected.to belong_to(:observation).class_name("Observ::Observation").optional }
  end

  describe "validations" do
    subject { build(:observ_score) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value) }

    it "validates uniqueness of name scoped to scoreable and source" do
      existing = create(:observ_score, name: "accuracy", source: :programmatic)
      duplicate = build(:observ_score,
        scoreable: existing.scoreable,
        name: "accuracy",
        source: :programmatic
      )
      expect(duplicate).not_to be_valid
    end

    it "allows same name with different source" do
      existing = create(:observ_score, name: "accuracy", source: :programmatic)
      different_source = build(:observ_score,
        scoreable: existing.scoreable,
        name: "accuracy",
        source: :manual
      )
      expect(different_source).to be_valid
    end

    it "allows same name and source for different scoreables" do
      create(:observ_score, name: "accuracy", source: :programmatic)
      different_scoreable = build(:observ_score,
        name: "accuracy",
        source: :programmatic
      )
      expect(different_scoreable).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:data_type).with_values(numeric: 0, boolean: 1, categorical: 2) }
    it { is_expected.to define_enum_for(:source).with_values(programmatic: 0, manual: 1, llm_judge: 2) }
  end

  describe "scopes" do
    let!(:session_score) { create(:observ_score, :for_session) }
    let!(:trace_score) { create(:observ_score, :for_trace) }
    let!(:run_item_score) { create(:observ_score, :for_dataset_run_item) }

    describe ".for_sessions" do
      it "returns only scores for sessions" do
        expect(described_class.for_sessions).to contain_exactly(session_score)
      end
    end

    describe ".for_traces" do
      it "returns only scores for traces" do
        expect(described_class.for_traces).to contain_exactly(trace_score)
      end
    end

    describe ".for_dataset_run_items" do
      it "returns only scores for dataset run items" do
        expect(described_class.for_dataset_run_items).to contain_exactly(run_item_score)
      end
    end
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

  describe "convenience accessors" do
    describe "#dataset_run_item" do
      it "returns scoreable when scoreable is a DatasetRunItem" do
        run_item = create(:observ_dataset_run_item)
        score = create(:observ_score, scoreable: run_item)
        expect(score.dataset_run_item).to eq(run_item)
      end

      it "returns nil when scoreable is not a DatasetRunItem" do
        session = create(:observ_session)
        score = create(:observ_score, scoreable: session)
        expect(score.dataset_run_item).to be_nil
      end
    end

    describe "#trace" do
      it "returns scoreable when scoreable is a Trace" do
        trace = create(:observ_trace)
        score = create(:observ_score, scoreable: trace)
        expect(score.trace).to eq(trace)
      end

      it "returns trace from DatasetRunItem when scoreable is a DatasetRunItem" do
        trace = create(:observ_trace)
        run_item = create(:observ_dataset_run_item, trace: trace)
        score = create(:observ_score, scoreable: run_item)
        expect(score.trace).to eq(trace)
      end

      it "returns nil when scoreable is a Session" do
        session = create(:observ_session)
        score = create(:observ_score, scoreable: session)
        expect(score.trace).to be_nil
      end
    end

    describe "#session" do
      it "returns scoreable when scoreable is a Session" do
        session = create(:observ_session)
        score = create(:observ_score, scoreable: session)
        expect(score.session).to eq(session)
      end

      it "returns observ_session when scoreable is a Trace" do
        session = create(:observ_session)
        trace = create(:observ_trace, observ_session: session)
        score = create(:observ_score, scoreable: trace)
        expect(score.session).to eq(session)
      end

      it "returns session from trace when scoreable is a DatasetRunItem" do
        session = create(:observ_session)
        trace = create(:observ_trace, observ_session: session)
        run_item = create(:observ_dataset_run_item, trace: trace)
        score = create(:observ_score, scoreable: run_item)
        expect(score.session).to eq(session)
      end
    end

    describe "#dataset_run" do
      it "delegates to dataset_run_item when present" do
        run_item = create(:observ_dataset_run_item)
        score = create(:observ_score, scoreable: run_item)
        expect(score.dataset_run).to eq(run_item.dataset_run)
      end

      it "returns nil when scoreable is not a DatasetRunItem" do
        trace = create(:observ_trace)
        score = create(:observ_score, scoreable: trace)
        expect(score.dataset_run).to be_nil
      end
    end

    describe "#dataset_item" do
      it "delegates to dataset_run_item when present" do
        run_item = create(:observ_dataset_run_item)
        score = create(:observ_score, scoreable: run_item)
        expect(score.dataset_item).to eq(run_item.dataset_item)
      end

      it "returns nil when scoreable is not a DatasetRunItem" do
        trace = create(:observ_trace)
        score = create(:observ_score, scoreable: trace)
        expect(score.dataset_item).to be_nil
      end
    end
  end
end
