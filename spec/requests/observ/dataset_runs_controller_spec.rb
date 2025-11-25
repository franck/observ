# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Observ::DatasetRunsController", type: :request do
  let!(:dataset) { create(:observ_dataset) }

  describe "GET /observ/datasets/:dataset_id/runs" do
    it "displays list of runs" do
      create(:observ_dataset_run, dataset: dataset, name: "run-v1")
      create(:observ_dataset_run, dataset: dataset, name: "run-v2")

      get observ_dataset_runs_path(dataset)

      expect(response).to be_successful
      expect(response.body).to include("run-v1")
      expect(response.body).to include("run-v2")
    end

    it "filters by status" do
      create(:observ_dataset_run, dataset: dataset, name: "completed-run", status: :completed)
      create(:observ_dataset_run, dataset: dataset, name: "pending-run", status: :pending)

      get observ_dataset_runs_path(dataset, status: "completed")

      expect(response).to be_successful
      expect(response.body).to include("completed-run")
      expect(response.body).not_to include("pending-run")
    end

    it "displays empty state when no runs" do
      get observ_dataset_runs_path(dataset)

      expect(response).to be_successful
      expect(response.body).to include("No runs found")
    end
  end

  describe "GET /observ/datasets/:dataset_id/runs/new" do
    it "displays new run form" do
      get new_observ_dataset_run_path(dataset)

      expect(response).to be_successful
      expect(response.body).to include("New Run")
    end

    it "shows item count" do
      create_list(:observ_dataset_item, 3, dataset: dataset, status: :active)

      get new_observ_dataset_run_path(dataset)

      expect(response).to be_successful
      expect(response.body).to include("3 active items")
    end
  end

  describe "POST /observ/datasets/:dataset_id/runs" do
    before do
      create_list(:observ_dataset_item, 3, dataset: dataset, status: :active)
      create(:observ_dataset_item, dataset: dataset, status: :archived)
    end

    it "creates new run and initializes run items" do
      expect {
        post observ_dataset_runs_path(dataset), params: {
          dataset_run: {
            name: "new-run",
            description: "Test run"
          }
        }
      }.to change(Observ::DatasetRun, :count).by(1)
        .and change(Observ::DatasetRunItem, :count).by(3)

      run = Observ::DatasetRun.last
      expect(run.name).to eq("new-run")
      expect(run.total_items).to eq(3)
      expect(response).to redirect_to(observ_dataset_run_path(dataset, run))
    end

    it "only includes active items" do
      post observ_dataset_runs_path(dataset), params: {
        dataset_run: {
          name: "new-run"
        }
      }

      run = Observ::DatasetRun.last
      expect(run.total_items).to eq(3) # excludes archived item
    end

    it "handles validation errors for duplicate name" do
      create(:observ_dataset_run, dataset: dataset, name: "existing-run")

      post observ_dataset_runs_path(dataset), params: {
        dataset_run: {
          name: "existing-run"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "handles validation errors for blank name" do
      post observ_dataset_runs_path(dataset), params: {
        dataset_run: {
          name: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /observ/datasets/:dataset_id/runs/:id" do
    let!(:run) { create(:observ_dataset_run, dataset: dataset, name: "test-run") }

    it "displays run details" do
      get observ_dataset_run_path(dataset, run)

      expect(response).to be_successful
      expect(response.body).to include("test-run")
    end

    it "displays run items" do
      item = create(:observ_dataset_item, dataset: dataset, input: { text: "test input" })
      create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      get observ_dataset_run_path(dataset, run)

      expect(response).to be_successful
      expect(response.body).to include("test input")
    end

    it "shows progress metrics" do
      run.update!(total_items: 10, completed_items: 7, failed_items: 2)

      get observ_dataset_run_path(dataset, run)

      expect(response).to be_successful
      expect(response.body).to include("7") # completed
      expect(response.body).to include("10") # total
    end
  end

  describe "DELETE /observ/datasets/:dataset_id/runs/:id" do
    let!(:run) { create(:observ_dataset_run, dataset: dataset, name: "test-run") }

    it "deletes run" do
      expect {
        delete observ_dataset_run_path(dataset, run)
      }.to change(Observ::DatasetRun, :count).by(-1)

      expect(response).to redirect_to(observ_dataset_path(dataset, tab: "runs"))
    end

    it "cascades delete to run items" do
      item = create(:observ_dataset_item, dataset: dataset)
      create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      expect {
        delete observ_dataset_run_path(dataset, run)
      }.to change(Observ::DatasetRunItem, :count).by(-1)
    end
  end
end
