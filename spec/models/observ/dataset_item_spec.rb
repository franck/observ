# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::DatasetItem, type: :model do
  describe "validations" do
    subject { build(:observ_dataset_item) }

    it { is_expected.to be_valid }

    it "requires input" do
      subject.input = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:input]).to include("can't be blank")
    end

    it "requires a dataset" do
      subject.dataset = nil
      expect(subject).not_to be_valid
    end

    it "does not require expected_output" do
      subject.expected_output = nil
      expect(subject).to be_valid
    end
  end

  describe "associations" do
    it "belongs to a dataset" do
      dataset = create(:observ_dataset)
      item = create(:observ_dataset_item, dataset: dataset)
      expect(item.dataset).to eq(dataset)
    end

    it "optionally belongs to a source trace" do
      session = create(:observ_session)
      trace = create(:observ_trace, observ_session: session)
      item = create(:observ_dataset_item, source_trace: trace)
      expect(item.source_trace).to eq(trace)
    end

    it "has many run_items" do
      item = create(:observ_dataset_item)
      run = create(:observ_dataset_run, dataset: item.dataset)
      run_item = create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      expect(item.run_items).to contain_exactly(run_item)
    end

    it "destroys run_items when destroyed" do
      item = create(:observ_dataset_item)
      run = create(:observ_dataset_run, dataset: item.dataset)
      create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      expect { item.destroy }.to change(Observ::DatasetRunItem, :count).by(-1)
    end
  end

  describe "enum status" do
    it "defaults to active" do
      item = create(:observ_dataset_item)
      expect(item).to be_active
    end

    it "can be archived" do
      item = create(:observ_dataset_item, :archived)
      expect(item).to be_archived
    end
  end

  describe "scopes" do
    let!(:dataset) { create(:observ_dataset) }
    let!(:active_item) { create(:observ_dataset_item, dataset: dataset, status: :active) }
    let!(:archived_item) { create(:observ_dataset_item, dataset: dataset, status: :archived) }

    describe ".active" do
      it "returns only active items" do
        expect(Observ::DatasetItem.active).to contain_exactly(active_item)
      end
    end

    describe ".archived" do
      it "returns only archived items" do
        expect(Observ::DatasetItem.archived).to contain_exactly(archived_item)
      end
    end
  end

  describe "#input_preview" do
    it "returns truncated JSON for hash input" do
      item = build(:observ_dataset_item, input: { text: "A" * 200 })
      preview = item.input_preview(max_length: 50)
      expect(preview.length).to eq(53) # 50 + "..."
      expect(preview).to end_with("...")
    end

    it "returns full text for short input" do
      item = build(:observ_dataset_item, input: { text: "Short" })
      preview = item.input_preview(max_length: 100)
      expect(preview).not_to end_with("...")
    end

    it "returns nil for blank input" do
      item = build(:observ_dataset_item)
      item.input = nil
      # Skip validation for this test
      expect(item.input_preview).to be_nil
    end
  end

  describe "#expected_output_preview" do
    it "returns truncated JSON for hash output" do
      item = build(:observ_dataset_item, expected_output: { answer: "B" * 200 })
      preview = item.expected_output_preview(max_length: 50)
      expect(preview.length).to eq(53)
      expect(preview).to end_with("...")
    end

    it "returns nil for blank expected_output" do
      item = build(:observ_dataset_item, expected_output: nil)
      expect(item.expected_output_preview).to be_nil
    end
  end

  describe "#run_count" do
    it "returns the number of runs this item participated in" do
      item = create(:observ_dataset_item)
      run1 = create(:observ_dataset_run, dataset: item.dataset)
      run2 = create(:observ_dataset_run, dataset: item.dataset)
      create(:observ_dataset_run_item, dataset_run: run1, dataset_item: item)
      create(:observ_dataset_run_item, dataset_run: run2, dataset_item: item)

      expect(item.run_count).to eq(2)
    end
  end

  describe "#last_run_item" do
    it "returns the most recent run item" do
      item = create(:observ_dataset_item)
      run1 = create(:observ_dataset_run, dataset: item.dataset)
      run2 = create(:observ_dataset_run, dataset: item.dataset)
      create(:observ_dataset_run_item, dataset_run: run1, dataset_item: item, created_at: 2.days.ago)
      recent = create(:observ_dataset_run_item, dataset_run: run2, dataset_item: item, created_at: 1.day.ago)

      expect(item.last_run_item).to eq(recent)
    end
  end

  describe "traits" do
    it "creates item with string input using :with_string_input trait" do
      item = create(:observ_dataset_item, :with_string_input)
      expect(item.input).to eq("Simple string input")
      expect(item.expected_output).to eq("Simple string output")
    end

    it "creates item with metadata using :with_metadata trait" do
      item = create(:observ_dataset_item, :with_metadata)
      expect(item.metadata).to include("category" => "geography")
    end
  end
end
