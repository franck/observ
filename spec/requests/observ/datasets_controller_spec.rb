# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Observ::DatasetsController", type: :request do
  describe "GET /observ/datasets" do
    it "displays list of datasets" do
      create(:observ_dataset, name: "test-dataset-1")
      create(:observ_dataset, name: "test-dataset-2")

      get observ_datasets_path

      expect(response).to be_successful
      expect(response.body).to include("test-dataset-1")
      expect(response.body).to include("test-dataset-2")
    end

    it "filters by search query" do
      create(:observ_dataset, name: "language-detection")
      create(:observ_dataset, name: "sentiment-analysis")

      get observ_datasets_path, params: { search: "language" }

      expect(response).to be_successful
      expect(response.body).to include("language-detection")
      expect(response.body).not_to include("sentiment-analysis")
    end

    it "displays empty state when no datasets" do
      get observ_datasets_path

      expect(response).to be_successful
      expect(response.body).to include("No datasets found")
      expect(response.body).to include("Create your first dataset")
    end
  end

  describe "GET /observ/datasets/new" do
    it "displays new dataset form" do
      get new_observ_dataset_path

      expect(response).to be_successful
      expect(response.body).to include("New Dataset")
    end
  end

  describe "POST /observ/datasets" do
    it "creates new dataset" do
      expect {
        post observ_datasets_path, params: {
          observ_dataset: {
            name: "new-dataset",
            description: "Test dataset",
            agent_class: "DummyAgent"
          }
        }
      }.to change(Observ::Dataset, :count).by(1)

      dataset = Observ::Dataset.last
      expect(response).to redirect_to(observ_dataset_path(dataset))
      follow_redirect!
      expect(response.body).to include("created successfully")
    end

    it "handles validation errors" do
      post observ_datasets_path, params: {
        observ_dataset: {
          name: "",
          agent_class: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("can&#39;t be blank")
    end

    it "validates agent_class exists" do
      post observ_datasets_path, params: {
        observ_dataset: {
          name: "test-dataset",
          agent_class: "NonExistentAgent"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be a valid agent class")
    end
  end

  describe "GET /observ/datasets/:id" do
    let!(:dataset) { create(:observ_dataset, name: "test-dataset") }

    it "displays dataset details" do
      get observ_dataset_path(dataset)

      expect(response).to be_successful
      expect(response.body).to include("test-dataset")
    end

    it "displays items tab by default" do
      create(:observ_dataset_item, dataset: dataset, input: { text: "test input" })

      get observ_dataset_path(dataset)

      expect(response).to be_successful
      expect(response.body).to include("test input")
    end

    it "displays runs tab when requested" do
      create(:observ_dataset_run, dataset: dataset, name: "run-v1")

      get observ_dataset_path(dataset, tab: "runs")

      expect(response).to be_successful
      expect(response.body).to include("run-v1")
    end
  end

  describe "GET /observ/datasets/:id/edit" do
    let!(:dataset) { create(:observ_dataset, name: "test-dataset") }

    it "displays edit form" do
      get edit_observ_dataset_path(dataset)

      expect(response).to be_successful
      expect(response.body).to include("Edit Dataset")
      expect(response.body).to include("test-dataset")
    end
  end

  describe "PATCH /observ/datasets/:id" do
    let!(:dataset) { create(:observ_dataset, name: "test-dataset") }

    it "updates dataset" do
      patch observ_dataset_path(dataset), params: {
        observ_dataset: {
          name: "updated-dataset",
          description: "Updated description"
        }
      }

      expect(dataset.reload.name).to eq("updated-dataset")
      expect(dataset.description).to eq("Updated description")
      expect(response).to redirect_to(observ_dataset_path(dataset))
    end

    it "handles validation errors" do
      patch observ_dataset_path(dataset), params: {
        observ_dataset: {
          name: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /observ/datasets/:id" do
    let!(:dataset) { create(:observ_dataset, name: "test-dataset") }

    it "deletes dataset" do
      expect {
        delete observ_dataset_path(dataset)
      }.to change(Observ::Dataset, :count).by(-1)

      expect(response).to redirect_to(observ_datasets_path)
      follow_redirect!
      expect(response.body).to include("deleted successfully")
    end

    it "cascades delete to items and runs" do
      create(:observ_dataset_item, dataset: dataset)
      create(:observ_dataset_run, dataset: dataset)

      expect {
        delete observ_dataset_path(dataset)
      }.to change(Observ::DatasetItem, :count).by(-1)
        .and change(Observ::DatasetRun, :count).by(-1)
    end
  end
end
