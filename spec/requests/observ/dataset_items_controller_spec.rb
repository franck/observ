# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Observ::DatasetItemsController", type: :request do
  let!(:dataset) { create(:observ_dataset) }

  describe "GET /observ/datasets/:dataset_id/items" do
    it "displays list of items" do
      create(:observ_dataset_item, dataset: dataset, input: { text: "input-1" })
      create(:observ_dataset_item, dataset: dataset, input: { text: "input-2" })

      get observ_dataset_items_path(dataset)

      expect(response).to be_successful
      expect(response.body).to include("input-1")
      expect(response.body).to include("input-2")
    end

    it "filters by status" do
      create(:observ_dataset_item, dataset: dataset, input: { text: "active-item" }, status: :active)
      create(:observ_dataset_item, dataset: dataset, input: { text: "archived-item" }, status: :archived)

      get observ_dataset_items_path(dataset, status: "active")

      expect(response).to be_successful
      expect(response.body).to include("active-item")
      expect(response.body).not_to include("archived-item")
    end

    it "displays empty state when no items" do
      get observ_dataset_items_path(dataset)

      expect(response).to be_successful
      expect(response.body).to include("No items found")
    end
  end

  describe "GET /observ/datasets/:dataset_id/items/new" do
    it "displays new item form" do
      get new_observ_dataset_item_path(dataset)

      expect(response).to be_successful
      expect(response.body).to include("Add Item")
    end
  end

  describe "POST /observ/datasets/:dataset_id/items" do
    it "creates new item with JSON input" do
      expect {
        post observ_dataset_items_path(dataset), params: {
          observ_dataset_item: {
            input_text: '{"text": "What is 2+2?"}',
            expected_output_text: '{"answer": "4"}',
            status: "active"
          }
        }
      }.to change(Observ::DatasetItem, :count).by(1)

      item = Observ::DatasetItem.last
      expect(item.input).to eq({ "text" => "What is 2+2?" })
      expect(item.expected_output).to eq({ "answer" => "4" })
      expect(response).to redirect_to(observ_dataset_path(dataset, tab: "items"))
    end

    it "creates new item with plain text input" do
      expect {
        post observ_dataset_items_path(dataset), params: {
          observ_dataset_item: {
            input_text: "Simple text input",
            expected_output_text: "Simple text output",
            status: "active"
          }
        }
      }.to change(Observ::DatasetItem, :count).by(1)

      item = Observ::DatasetItem.last
      expect(item.input).to eq("Simple text input")
      expect(item.expected_output).to eq("Simple text output")
    end

    it "handles validation errors" do
      post observ_dataset_items_path(dataset), params: {
        observ_dataset_item: {
          input_text: "",
          status: "active"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /observ/datasets/:dataset_id/items/:id/edit" do
    let!(:item) { create(:observ_dataset_item, dataset: dataset) }

    it "displays edit form" do
      get edit_observ_dataset_item_path(dataset, item)

      expect(response).to be_successful
      expect(response.body).to include("Edit Item")
    end
  end

  describe "PATCH /observ/datasets/:dataset_id/items/:id" do
    let!(:item) { create(:observ_dataset_item, dataset: dataset, input: { text: "original" }) }

    it "updates item" do
      patch observ_dataset_item_path(dataset, item), params: {
        observ_dataset_item: {
          input_text: '{"text": "updated"}',
          status: "archived"
        }
      }

      expect(item.reload.input).to eq({ "text" => "updated" })
      expect(item.status).to eq("archived")
      expect(response).to redirect_to(observ_dataset_path(dataset, tab: "items"))
    end

    it "preserves input when not provided in update" do
      original_input = item.input
      patch observ_dataset_item_path(dataset, item), params: {
        observ_dataset_item: {
          status: "archived"
        }
      }

      expect(item.reload.input).to eq(original_input)
      expect(item.status).to eq("archived")
      expect(response).to redirect_to(observ_dataset_path(dataset, tab: "items"))
    end
  end

  describe "DELETE /observ/datasets/:dataset_id/items/:id" do
    let!(:item) { create(:observ_dataset_item, dataset: dataset) }

    it "deletes item" do
      expect {
        delete observ_dataset_item_path(dataset, item)
      }.to change(Observ::DatasetItem, :count).by(-1)

      expect(response).to redirect_to(observ_dataset_path(dataset, tab: "items"))
    end
  end
end
