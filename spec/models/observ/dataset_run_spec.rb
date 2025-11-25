# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::DatasetRun, type: :model do
  describe "validations" do
    subject { build(:observ_dataset_run) }

    it { is_expected.to be_valid }

    it "requires a name" do
      subject.name = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:name]).to include("can't be blank")
    end

    it "requires a unique name within the dataset" do
      dataset = create(:observ_dataset)
      create(:observ_dataset_run, dataset: dataset, name: "v1")
      duplicate = build(:observ_dataset_run, dataset: dataset, name: "v1")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "allows same name in different datasets" do
      dataset1 = create(:observ_dataset)
      dataset2 = create(:observ_dataset)
      create(:observ_dataset_run, dataset: dataset1, name: "v1")
      run2 = build(:observ_dataset_run, dataset: dataset2, name: "v1")

      expect(run2).to be_valid
    end
  end

  describe "associations" do
    it "belongs to a dataset" do
      dataset = create(:observ_dataset)
      run = create(:observ_dataset_run, dataset: dataset)
      expect(run.dataset).to eq(dataset)
    end

    it "has many run_items" do
      run = create(:observ_dataset_run)
      item = create(:observ_dataset_item, dataset: run.dataset)
      run_item = create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      expect(run.run_items).to contain_exactly(run_item)
    end

    it "has many items through run_items" do
      run = create(:observ_dataset_run)
      item = create(:observ_dataset_item, dataset: run.dataset)
      create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      expect(run.items).to contain_exactly(item)
    end

    it "destroys run_items when destroyed" do
      run = create(:observ_dataset_run, :with_run_items, run_items_count: 2)
      expect { run.destroy }.to change(Observ::DatasetRunItem, :count).by(-2)
    end
  end

  describe "enum status" do
    it "defaults to pending" do
      run = create(:observ_dataset_run)
      expect(run).to be_pending
    end

    it "can be running" do
      run = create(:observ_dataset_run, :running)
      expect(run).to be_running
    end

    it "can be completed" do
      run = create(:observ_dataset_run, :completed)
      expect(run).to be_completed
    end

    it "can be failed" do
      run = create(:observ_dataset_run, :failed)
      expect(run).to be_failed
    end
  end

  describe "#progress_percentage" do
    it "returns 0 when total_items is zero" do
      run = build(:observ_dataset_run, total_items: 0)
      expect(run.progress_percentage).to eq(0)
    end

    it "calculates percentage based on completed and failed items" do
      run = build(:observ_dataset_run, total_items: 10, completed_items: 3, failed_items: 2)
      expect(run.progress_percentage).to eq(50.0)
    end

    it "returns 100 when all items are processed" do
      run = build(:observ_dataset_run, total_items: 5, completed_items: 4, failed_items: 1)
      expect(run.progress_percentage).to eq(100.0)
    end
  end

  describe "#finished?" do
    it "returns true when completed" do
      run = build(:observ_dataset_run, :completed)
      expect(run.finished?).to be true
    end

    it "returns true when failed" do
      run = build(:observ_dataset_run, :failed)
      expect(run.finished?).to be true
    end

    it "returns false when pending" do
      run = build(:observ_dataset_run, status: :pending)
      expect(run.finished?).to be false
    end

    it "returns false when running" do
      run = build(:observ_dataset_run, :running)
      expect(run.finished?).to be false
    end
  end

  describe "#in_progress?" do
    it "returns true when pending" do
      run = build(:observ_dataset_run, status: :pending)
      expect(run.in_progress?).to be true
    end

    it "returns true when running" do
      run = build(:observ_dataset_run, :running)
      expect(run.in_progress?).to be true
    end

    it "returns false when completed" do
      run = build(:observ_dataset_run, :completed)
      expect(run.in_progress?).to be false
    end
  end

  describe "#update_metrics!" do
    it "updates completed and failed counts from run_items" do
      run = create(:observ_dataset_run)
      item1 = create(:observ_dataset_item, dataset: run.dataset)
      item2 = create(:observ_dataset_item, dataset: run.dataset)
      item3 = create(:observ_dataset_item, dataset: run.dataset)

      session = create(:observ_session)
      trace = create(:observ_trace, observ_session: session, total_cost: 0.001, total_tokens: 100)

      create(:observ_dataset_run_item, dataset_run: run, dataset_item: item1, trace: trace)
      create(:observ_dataset_run_item, dataset_run: run, dataset_item: item2, error: "Failed")
      create(:observ_dataset_run_item, dataset_run: run, dataset_item: item3) # pending

      run.update_metrics!

      expect(run.completed_items).to eq(1)
      expect(run.failed_items).to eq(1)
      expect(run.total_cost).to eq(0.001)
      expect(run.total_tokens).to eq(100)
    end
  end

  describe "#initialize_run_items!" do
    it "creates run_items for all active dataset items" do
      dataset = create(:observ_dataset)
      create_list(:observ_dataset_item, 3, dataset: dataset, status: :active)
      create(:observ_dataset_item, dataset: dataset, status: :archived)
      run = create(:observ_dataset_run, dataset: dataset)

      expect { run.initialize_run_items! }.to change(Observ::DatasetRunItem, :count).by(3)
      expect(run.total_items).to eq(3)
    end

    it "does not duplicate existing run_items" do
      dataset = create(:observ_dataset)
      item = create(:observ_dataset_item, dataset: dataset)
      run = create(:observ_dataset_run, dataset: dataset)
      create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      expect { run.initialize_run_items! }.not_to change(Observ::DatasetRunItem, :count)
    end
  end

  describe "#success_rate" do
    it "returns 0 when total_items is zero" do
      run = build(:observ_dataset_run, total_items: 0)
      expect(run.success_rate).to eq(0)
    end

    it "calculates success rate correctly" do
      run = build(:observ_dataset_run, total_items: 10, completed_items: 8)
      expect(run.success_rate).to eq(80.0)
    end
  end

  describe "#failure_rate" do
    it "returns 0 when total_items is zero" do
      run = build(:observ_dataset_run, total_items: 0)
      expect(run.failure_rate).to eq(0)
    end

    it "calculates failure rate correctly" do
      run = build(:observ_dataset_run, total_items: 10, failed_items: 2)
      expect(run.failure_rate).to eq(20.0)
    end
  end

  describe "#pending_items_count" do
    it "calculates pending items correctly" do
      run = build(:observ_dataset_run, total_items: 10, completed_items: 5, failed_items: 2)
      expect(run.pending_items_count).to eq(3)
    end
  end

  describe "traits" do
    it "creates completed run with :completed trait" do
      run = create(:observ_dataset_run, :completed)
      expect(run).to be_completed
      expect(run.total_items).to eq(5)
    end

    it "creates run with items using :with_run_items trait" do
      run = create(:observ_dataset_run, :with_run_items, run_items_count: 4)
      expect(run.run_items.count).to eq(4)
      expect(run.total_items).to eq(4)
    end
  end
end
