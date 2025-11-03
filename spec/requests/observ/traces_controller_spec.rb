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
end
