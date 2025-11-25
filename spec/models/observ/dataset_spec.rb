# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Dataset, type: :model do
  describe "validations" do
    subject { build(:observ_dataset) }

    it { is_expected.to be_valid }

    it "requires a name" do
      subject.name = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:name]).to include("can't be blank")
    end

    it "requires a unique name" do
      create(:observ_dataset, name: "unique_name")
      subject.name = "unique_name"
      expect(subject).not_to be_valid
      expect(subject.errors[:name]).to include("has already been taken")
    end

    it "requires an agent_class" do
      subject.agent_class = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:agent_class]).to include("can't be blank")
    end

    it "validates agent_class exists" do
      subject.agent_class = "NonExistentAgent"
      expect(subject).not_to be_valid
      expect(subject.errors[:agent_class]).to include("must be a valid agent class")
    end

    it "accepts a valid agent_class" do
      subject.agent_class = "DummyAgent"
      expect(subject).to be_valid
    end
  end

  describe "associations" do
    it "has many items" do
      dataset = create(:observ_dataset)
      item1 = create(:observ_dataset_item, dataset: dataset)
      item2 = create(:observ_dataset_item, dataset: dataset)

      expect(dataset.items).to contain_exactly(item1, item2)
    end

    it "has many runs" do
      dataset = create(:observ_dataset)
      run1 = create(:observ_dataset_run, dataset: dataset)
      run2 = create(:observ_dataset_run, dataset: dataset)

      expect(dataset.runs).to contain_exactly(run1, run2)
    end

    it "destroys items when destroyed" do
      dataset = create(:observ_dataset, :with_items, items_count: 2)
      expect { dataset.destroy }.to change(Observ::DatasetItem, :count).by(-2)
    end

    it "destroys runs when destroyed" do
      dataset = create(:observ_dataset, :with_runs, runs_count: 2)
      expect { dataset.destroy }.to change(Observ::DatasetRun, :count).by(-2)
    end
  end

  describe "#agent" do
    it "returns the agent class constant" do
      dataset = build(:observ_dataset, agent_class: "DummyAgent")
      expect(dataset.agent).to eq(DummyAgent)
    end
  end

  describe "#active_items" do
    it "returns only active items" do
      dataset = create(:observ_dataset)
      active_item = create(:observ_dataset_item, dataset: dataset, status: :active)
      create(:observ_dataset_item, dataset: dataset, status: :archived)

      expect(dataset.active_items).to contain_exactly(active_item)
    end
  end

  describe "#items_count" do
    it "returns the total number of items" do
      dataset = create(:observ_dataset, :with_items, items_count: 3)
      expect(dataset.items_count).to eq(3)
    end
  end

  describe "#active_items_count" do
    it "returns the number of active items" do
      dataset = create(:observ_dataset)
      create_list(:observ_dataset_item, 2, dataset: dataset, status: :active)
      create(:observ_dataset_item, dataset: dataset, status: :archived)

      expect(dataset.active_items_count).to eq(2)
    end
  end

  describe "#runs_count" do
    it "returns the total number of runs" do
      dataset = create(:observ_dataset, :with_runs, runs_count: 2)
      expect(dataset.runs_count).to eq(2)
    end
  end

  describe "#last_run" do
    it "returns the most recent run" do
      dataset = create(:observ_dataset)
      create(:observ_dataset_run, dataset: dataset, created_at: 2.days.ago)
      recent_run = create(:observ_dataset_run, dataset: dataset, created_at: 1.day.ago)

      expect(dataset.last_run).to eq(recent_run)
    end

    it "returns nil when no runs exist" do
      dataset = create(:observ_dataset)
      expect(dataset.last_run).to be_nil
    end
  end

  describe "traits" do
    it "creates dataset with items using :with_items trait" do
      dataset = create(:observ_dataset, :with_items, items_count: 5)
      expect(dataset.items.count).to eq(5)
    end

    it "creates dataset with runs using :with_runs trait" do
      dataset = create(:observ_dataset, :with_runs, runs_count: 3)
      expect(dataset.runs.count).to eq(3)
    end
  end
end
