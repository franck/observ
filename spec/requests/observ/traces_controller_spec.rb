require 'rails_helper'

RSpec.describe Observ::TracesController, type: :request do
  let!(:session1) { create(:observ_session) }
  let!(:session2) { create(:observ_session) }
  let!(:trace1) { create(:observ_trace, observ_session: session1, name: "Chat Request", start_time: 1.hour.ago) }
  let!(:trace2) { create(:observ_trace, observ_session: session2, name: "Background Job", start_time: 2.hours.ago) }
  let!(:generation1) { create(:observ_generation, trace: trace1) }
  let!(:span1) { create(:observ_span, trace: trace1) }

  describe "GET /observ/traces" do
    it "returns success" do
      get observ_traces_path
      expect(response).to have_http_status(:success)
    end

    it "displays all traces" do
      get observ_traces_path
      expect(response.body).to include(trace1.trace_id[0..11])
      expect(response.body).to include(trace2.trace_id[0..11])
    end

    it "displays traces ordered by start time" do
      get observ_traces_path
      expect(response.body).to include("Traces")
      expect(response.body).to include(trace1.name)
    end

    it "displays associated session" do
      get observ_traces_path
      expect(response.body).to include(session1.session_id[0..7])
    end

    it "paginates traces" do
      create_list(:observ_trace, 30, observ_session: session1)
      get observ_traces_path
      expect(response).to have_http_status(:success)
    end

    context "with filters" do
      it "filters by session_id" do
        get observ_traces_path, params: { filter: { session_id: session1.session_id } }
        expect(response.body).to include(trace1.trace_id[0..11])
      end

      it "filters by name" do
        get observ_traces_path, params: { filter: { name: "Chat Request" } }
        expect(response.body).to include(trace1.trace_id[0..11])
      end

      it "filters by start_date" do
        get observ_traces_path, params: { filter: { start_date: 90.minutes.ago } }
        expect(response.body).to include(trace1.trace_id[0..11])
      end

      it "filters by end_date" do
        get observ_traces_path, params: { filter: { end_date: 90.minutes.ago } }
        expect(response).to have_http_status(:success)
      end

      it "handles non-existent session_id gracefully" do
        get observ_traces_path, params: { filter: { session_id: "non-existent" } }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /observ/traces/:id" do
    it "returns success" do
      get observ_trace_path(trace1)
      expect(response).to have_http_status(:success)
    end

    it "displays the trace" do
      get observ_trace_path(trace1)
      expect(response.body).to include(trace1.trace_id[0..11])
    end

    it "displays observations" do
      get observ_trace_path(trace1)
      expect(response.body).to include(generation1.observation_id[0..7])
      expect(response.body).to include(span1.observation_id[0..7])
    end

    it "displays generations section" do
      get observ_trace_path(trace1)
      expect(response.body).to include("Generation")
    end

    it "displays spans section" do
      get observ_trace_path(trace1)
      expect(response.body).to include("Span")
    end

    it "returns 404 for non-existent trace" do
      get observ_trace_path(id: 999999)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /observ/traces/search" do
    it "returns success" do
      get search_observ_traces_path, params: { q: "Chat" }
      expect(response).to have_http_status(:success)
    end

    it "searches by trace_id" do
      get search_observ_traces_path, params: { q: trace1.trace_id[0..5] }
      expect(response.body).to include(trace1.trace_id[0..11])
    end

    it "searches by name" do
      get search_observ_traces_path, params: { q: "Chat" }
      expect(response.body).to include(trace1.trace_id[0..11])
    end

    it "limits results to 50" do
      create_list(:observ_trace, 60, observ_session: session1, name: "Test")
      get search_observ_traces_path, params: { q: "Test" }
      expect(response).to have_http_status(:success)
    end

    it "returns empty when no matches" do
      get search_observ_traces_path, params: { q: "NonExistent" }
      expect(response.body).to include("No traces found")
    end
  end

  describe "GET /observ/traces/:id/add_to_dataset_drawer" do
    let!(:dataset) { create(:observ_dataset) }
    let(:turbo_stream_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

    it "returns success" do
      get add_to_dataset_drawer_observ_trace_path(trace1), headers: turbo_stream_headers
      expect(response).to have_http_status(:success)
    end

    it "displays available datasets" do
      get add_to_dataset_drawer_observ_trace_path(trace1), headers: turbo_stream_headers
      expect(response.body).to include(dataset.name)
    end

    it "shows a message when no datasets exist" do
      Observ::Dataset.destroy_all
      get add_to_dataset_drawer_observ_trace_path(trace1), headers: turbo_stream_headers
      expect(response.body).to include("No datasets available")
    end

    it "returns 404 for non-existent trace" do
      get add_to_dataset_drawer_observ_trace_path(id: 999999), headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /observ/traces/:id/add_to_dataset" do
    let!(:dataset) { create(:observ_dataset) }
    let(:trace_with_data) do
      create(:observ_trace,
        observ_session: session1,
        input: { "text" => "What is 2+2?" }.to_json,
        output: { "answer" => "4" }.to_json
      )
    end

    it "creates a dataset item from the trace" do
      expect {
        post add_to_dataset_observ_trace_path(trace_with_data), params: { dataset_id: dataset.id }
      }.to change(Observ::DatasetItem, :count).by(1)
    end

    it "redirects to the dataset page on success" do
      post add_to_dataset_observ_trace_path(trace_with_data), params: { dataset_id: dataset.id }
      expect(response).to redirect_to(observ_dataset_path(dataset, tab: "items"))
    end

    it "sets the source_trace reference" do
      post add_to_dataset_observ_trace_path(trace_with_data), params: { dataset_id: dataset.id }
      item = Observ::DatasetItem.last
      expect(item.source_trace).to eq(trace_with_data)
    end

    it "uses trace input as item input" do
      post add_to_dataset_observ_trace_path(trace_with_data), params: { dataset_id: dataset.id }
      item = Observ::DatasetItem.last
      expect(item.input).to eq(trace_with_data.input)
    end

    it "uses trace output as expected_output by default" do
      post add_to_dataset_observ_trace_path(trace_with_data), params: { dataset_id: dataset.id }
      item = Observ::DatasetItem.last
      expect(item.expected_output).to eq(trace_with_data.output)
    end

    it "allows custom expected_output" do
      custom_output = { "answer" => "four" }.to_json
      post add_to_dataset_observ_trace_path(trace_with_data), params: {
        dataset_id: dataset.id,
        expected_output: custom_output
      }
      item = Observ::DatasetItem.last
      expect(item.expected_output).to eq(custom_output)
    end

    it "creates item with active status" do
      post add_to_dataset_observ_trace_path(trace_with_data), params: { dataset_id: dataset.id }
      item = Observ::DatasetItem.last
      expect(item.status).to eq("active")
    end

    it "returns 404 for non-existent trace" do
      post add_to_dataset_observ_trace_path(id: 999999), params: { dataset_id: dataset.id }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for non-existent dataset" do
      post add_to_dataset_observ_trace_path(trace_with_data), params: { dataset_id: 999999 }
      expect(response).to have_http_status(:not_found)
    end
  end
end
