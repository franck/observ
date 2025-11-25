# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Observ::DatasetRunItemsController", type: :request do
  let!(:dataset) { create(:observ_dataset) }
  let!(:run) { create(:observ_dataset_run, dataset: dataset) }
  let!(:dataset_item) { create(:observ_dataset_item, dataset: dataset, input: { text: "test input" }, expected_output: { result: "expected" }) }
  let!(:run_item) { create(:observ_dataset_run_item, dataset_run: run, dataset_item: dataset_item) }

  let(:turbo_stream_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

  describe "GET /observ/datasets/:dataset_id/runs/:run_id/run_items/:id/details_drawer" do
    it "returns success" do
      get details_drawer_observ_dataset_run_run_item_path(dataset, run, run_item), headers: turbo_stream_headers

      expect(response).to have_http_status(:success)
    end

    it "displays input" do
      get details_drawer_observ_dataset_run_run_item_path(dataset, run, run_item), headers: turbo_stream_headers

      expect(response.body).to include("test input")
    end

    it "displays expected output" do
      get details_drawer_observ_dataset_run_run_item_path(dataset, run, run_item), headers: turbo_stream_headers

      expect(response.body).to include("expected")
    end

    it "displays status" do
      get details_drawer_observ_dataset_run_run_item_path(dataset, run, run_item), headers: turbo_stream_headers

      expect(response.body).to include("pending")
    end

    context "with failed run item" do
      before do
        run_item.update!(error: "Something went wrong")
      end

      it "displays error message" do
        get details_drawer_observ_dataset_run_run_item_path(dataset, run, run_item), headers: turbo_stream_headers

        expect(response.body).to include("Something went wrong")
      end
    end

    context "with completed run item" do
      let(:session) { create(:observ_session) }
      let(:trace) { create(:observ_trace, observ_session: session, output: { result: "actual output" }.to_json) }

      before do
        run_item.update!(trace: trace)
      end

      it "displays actual output" do
        get details_drawer_observ_dataset_run_run_item_path(dataset, run, run_item), headers: turbo_stream_headers

        expect(response.body).to include("actual output")
      end

      it "displays link to trace" do
        get details_drawer_observ_dataset_run_run_item_path(dataset, run, run_item), headers: turbo_stream_headers

        expect(response.body).to include("View Full Trace")
      end
    end
  end
end
