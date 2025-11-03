require 'rails_helper'

RSpec.describe Observ::SessionsController, type: :request do
  let!(:session1) { create(:observ_session, user_id: "user-1", start_time: 1.hour.ago, total_tokens: 1000, total_cost: 0.05) }
  let!(:session2) { create(:observ_session, user_id: "user-2", start_time: 2.hours.ago, total_tokens: 2000, total_cost: 0.10) }
  let!(:trace1) { create(:observ_trace, observ_session: session1) }
  let!(:trace2) { create(:observ_trace, observ_session: session2) }

  describe "GET /observ/sessions" do
    it "returns success" do
      get observ_sessions_path
      expect(response).to have_http_status(:success)
    end

    it "displays all sessions" do
      get observ_sessions_path
      expect(response.body).to include(session1.session_id[0..11])
      expect(response.body).to include(session2.session_id[0..11])
    end

    it "displays sessions ordered by start time" do
      get observ_sessions_path
      expect(response.body).to include("Sessions")
      expect(response.body).to include(session1.session_id[0..11])
    end

    it "paginates sessions" do
      create_list(:observ_session, 30)
      get observ_sessions_path
      expect(response).to have_http_status(:success)
    end

    context "with filters" do
      it "filters by user_id" do
        get observ_sessions_path, params: { filter: { user_id: "user-1" } }
        expect(response.body).to include(session1.session_id[0..11])
      end

      it "filters by start_date" do
        get observ_sessions_path, params: { filter: { start_date: 90.minutes.ago } }
        expect(response.body).to include(session1.session_id[0..11])
      end

      it "filters by end_date" do
        get observ_sessions_path, params: { filter: { end_date: 90.minutes.ago } }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /observ/sessions/:id" do
    it "returns success" do
      get observ_session_path(session1)
      expect(response).to have_http_status(:success)
    end

    it "displays the session" do
      get observ_session_path(session1)
      expect(response.body).to include(session1.session_id[0..11])
    end

    it "displays session traces" do
      get observ_session_path(session1)
      expect(response.body).to include(trace1.trace_id[0..11])
    end

    it "displays session information" do
      get observ_session_path(session1)
      expect(response.body).to include("Traces")
    end

    it "returns 404 for non-existent session" do
      get observ_session_path(id: 999999)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /observ/sessions/:id/metrics" do
    it "returns JSON metrics" do
      get metrics_observ_session_path(session1)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to match(/application\/json/)
    end

    it "returns session metrics data" do
      get metrics_observ_session_path(session1)
      json = JSON.parse(response.body)
      expect(json).to be_a(Hash)
    end
  end
end
