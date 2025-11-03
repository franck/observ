require 'rails_helper'

RSpec.describe Observ::DashboardController, type: :request do
  let!(:session1) { create(:observ_session, start_time: 1.hour.ago, total_tokens: 1000, total_cost: 0.05) }
  let!(:session2) { create(:observ_session, start_time: 2.days.ago, total_tokens: 2000, total_cost: 0.10) }
  let!(:trace1) { create(:observ_trace, observ_session: session1) }
  let!(:trace2) { create(:observ_trace, observ_session: session2) }
  let!(:generation1) { create(:observ_generation, trace: trace1, model: "gpt-4", cost_usd: 0.03, start_time: 1.hour.ago, end_time: 1.hour.ago + 1.second) }
  let!(:generation2) { create(:observ_generation, trace: trace2, model: "gpt-3.5-turbo", cost_usd: 0.01, start_time: 2.days.ago, end_time: 2.days.ago + 2.seconds) }

  describe "GET /observ" do
    it "returns success" do
      get observ_root_path
      expect(response).to have_http_status(:success)
    end

    it "displays dashboard metrics" do
      get observ_root_path
      expect(response.body).to include("Sessions")
      expect(response.body).to include("Traces")
      expect(response.body).to include("Tokens")
    end

    it "displays recent sessions" do
      get observ_root_path
      expect(response.body).to include(session1.session_id[0..11])
      expect(response.body).to include(session2.session_id[0..11])
    end

    it "filters by time period" do
      get observ_root_path, params: { period: "24h" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sessions")
    end

    it "displays cost information" do
      get observ_root_path
      expect(response.body).to include("Cost")
    end

    it "displays token usage" do
      get observ_root_path
      expect(response.body).to include("Token")
    end
  end

  describe "GET /observ/dashboard" do
    it "returns success" do
      get observ_dashboard_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /observ/dashboard/metrics" do
    it "returns JSON metrics" do
      get "/observ/dashboard/metrics"
      expect(response).to have_http_status(:success)
      expect(response.content_type).to match(/application\/json/)
    end

    it "includes expected metrics" do
      get "/observ/dashboard/metrics"
      json = JSON.parse(response.body)
      expect(json).to include("total_sessions", "total_traces", "total_llm_calls", "total_tokens", "total_cost")
    end

    it "includes trends data" do
      get "/observ/dashboard/metrics"
      json = JSON.parse(response.body)
      expect(json["trends"]).to include("sessions", "tokens", "cost")
    end
  end

  describe "GET /observ/dashboard/cost_analysis" do
    it "returns JSON cost analysis" do
      get "/observ/dashboard/cost_analysis"
      expect(response).to have_http_status(:success)
      expect(response.content_type).to match(/application\/json/)
    end

    it "includes cost by model" do
      get "/observ/dashboard/cost_analysis"
      json = JSON.parse(response.body)
      expect(json).to have_key("by_model")
      expect(json["by_model"]).to be_a(Hash)
    end

    it "includes cost over time" do
      get "/observ/dashboard/cost_analysis"
      json = JSON.parse(response.body)
      expect(json).to have_key("over_time")
      expect(json["over_time"]).to be_a(Hash)
    end
  end

  describe "metrics calculations" do
    context "with 24h period" do
      it "only includes recent sessions" do
        get "/observ/dashboard/metrics?period=24h"
        json = JSON.parse(response.body)
        expect(json["total_sessions"]).to be >= 1
      end
    end

    context "with 7d period" do
      it "includes sessions from last 7 days" do
        get "/observ/dashboard/metrics", params: { period: "7d" }
        json = JSON.parse(response.body)
        expect(json["total_sessions"]).to eq(2)
      end
    end

    context "with no data" do
      before do
        Observ::Session.destroy_all
      end

      it "handles empty metrics gracefully" do
        get "/observ/dashboard/metrics"
        json = JSON.parse(response.body)
        expect(json["total_sessions"]).to eq(0)
        expect(json["total_cost"]).to eq(0)
      end
    end
  end
end
