require 'rails_helper'

RSpec.describe Observ::ObservationsController, type: :request do
  let!(:session1) { create(:observ_session) }
  let!(:trace1) { create(:observ_trace, observ_session: session1) }
  let!(:trace2) { create(:observ_trace, observ_session: session1) }
  let!(:generation1) { create(:observ_generation, trace: trace1, name: "Chat Completion", model: "gpt-4", start_time: 1.hour.ago) }
  let!(:generation2) { create(:observ_generation, trace: trace2, name: "Embedding", model: "text-embedding-ada", start_time: 2.hours.ago) }
  let!(:span1) { create(:observ_span, trace: trace1, name: "Database Query", start_time: 3.hours.ago) }

  describe "GET /observ/observations" do
    it "returns success" do
      get observ_observations_path
      expect(response).to have_http_status(:success)
    end

    it "displays all observations" do
      get observ_observations_path
      expect(response.body).to include(generation1.observation_id[0..11])
      expect(response.body).to include(generation2.observation_id[0..11])
      expect(response.body).to include(span1.observation_id[0..11])
    end

    it "displays observations ordered by start time" do
      get observ_observations_path
      expect(response.body).to include("Observations")
      expect(response.body).to include(generation1.name)
    end

    it "displays associated trace" do
      get observ_observations_path
      expect(response.body).to include(trace1.trace_id[0..7])
    end

    it "paginates observations" do
      create_list(:observ_generation, 30, trace: trace1)
      get observ_observations_path
      expect(response).to have_http_status(:success)
    end

    context "with filters" do
      it "filters by type" do
        get observ_observations_path, params: { filter: { type: "Observ::Generation" } }
        expect(response.body).to include(generation1.observation_id[0..11])
        expect(response.body).to include(generation2.observation_id[0..11])
      end

      it "filters by name" do
        get observ_observations_path, params: { filter: { name: "Chat Completion" } }
        expect(response.body).to include(generation1.observation_id[0..11])
      end

      it "filters by model" do
        get observ_observations_path, params: { filter: { model: "gpt-4" } }
        expect(response.body).to include(generation1.observation_id[0..11])
      end

      it "filters by start_date" do
        get observ_observations_path, params: { filter: { start_date: 90.minutes.ago } }
        expect(response.body).to include(generation1.observation_id[0..11])
      end

      it "filters by end_date" do
        get observ_observations_path, params: { filter: { end_date: 90.minutes.ago } }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /observ/observations/:id" do
    context "with a generation" do
      it "returns success" do
        get observ_observation_path(generation1)
        expect(response).to have_http_status(:success)
      end

      it "displays the observation" do
        get observ_observation_path(generation1)
        expect(response.body).to include(generation1.observation_id[0..11])
      end

      it "displays generation details" do
        get observ_observation_path(generation1)
        expect(response.body).to include(generation1.model)
      end
    end

    context "with a span" do
      it "returns success" do
        get observ_observation_path(span1)
        expect(response).to have_http_status(:success)
      end

      it "displays span details" do
        get observ_observation_path(span1)
        expect(response.body).to include(span1.observation_id[0..11])
      end
    end

    it "returns 404 for non-existent observation" do
      get observ_observation_path(id: 999999)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /observ/observations/generations" do
    it "returns success" do
      get generations_observ_observations_path
      expect(response).to have_http_status(:success)
    end

    it "only displays generations" do
      get generations_observ_observations_path
      expect(response.body).to include(generation1.observation_id[0..11])
      expect(response.body).to include(generation2.observation_id[0..11])
    end

    it "displays observations page" do
      get generations_observ_observations_path
      expect(response.body).to include("Observations")
    end

    it "paginates generations" do
      create_list(:observ_generation, 30, trace: trace1)
      get generations_observ_observations_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /observ/observations/spans" do
    it "returns success" do
      get spans_observ_observations_path
      expect(response).to have_http_status(:success)
    end

    it "only displays spans" do
      get spans_observ_observations_path
      expect(response.body).to include(span1.observation_id[0..11])
    end

    it "displays observations page" do
      get spans_observ_observations_path
      expect(response.body).to include("Observations")
    end

    it "paginates spans" do
      create_list(:observ_span, 30, trace: trace1)
      get spans_observ_observations_path
      expect(response).to have_http_status(:success)
    end
  end
end
