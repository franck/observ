# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::ScoresController, type: :request do
  describe "POST /sessions/:session_id/scores" do
    let(:session) { create(:observ_session) }

    it "creates a score for the session" do
      expect {
        post observ_session_scores_path(session), params: { value: "1", data_type: "boolean", name: "manual" }
      }.to change(Observ::Score, :count).by(1)

      score = Observ::Score.last
      expect(score.scoreable).to eq(session)
      expect(score.value).to eq(1.0)
      expect(score.data_type).to eq("boolean")
      expect(score.source).to eq("manual")
    end

    it "creates a passing score when value is 1" do
      post observ_session_scores_path(session), params: { value: "1", data_type: "boolean" }

      score = Observ::Score.last
      expect(score.value).to eq(1.0)
      expect(score.passed?).to be true
    end

    it "creates a failing score when value is 0" do
      post observ_session_scores_path(session), params: { value: "0", data_type: "boolean" }

      score = Observ::Score.last
      expect(score.value).to eq(0.0)
      expect(score.failed?).to be true
    end

    it "saves the comment" do
      post observ_session_scores_path(session), params: { value: "1", data_type: "boolean", comment: "Great output!" }

      score = Observ::Score.last
      expect(score.comment).to eq("Great output!")
    end

    it "saves the created_by" do
      post observ_session_scores_path(session), params: { value: "1", data_type: "boolean", created_by: "test_user" }

      score = Observ::Score.last
      expect(score.created_by).to eq("test_user")
    end

    it "updates existing score instead of creating new one" do
      existing = create(:observ_score, scoreable: session, name: "manual", source: :manual, value: 1.0)

      expect {
        post observ_session_scores_path(session), params: { value: "0", data_type: "boolean", name: "manual" }
      }.not_to change(Observ::Score, :count)

      existing.reload
      expect(existing.value).to eq(0.0)
    end

    it "responds with turbo_stream format" do
      post observ_session_scores_path(session), params: { value: "1", data_type: "boolean" }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "redirects back with html format" do
      post observ_session_scores_path(session), params: { value: "1", data_type: "boolean" }

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to eq("Score saved.")
    end
  end

  describe "POST /traces/:trace_id/scores" do
    let(:trace) { create(:observ_trace) }

    it "creates a score for the trace" do
      expect {
        post observ_trace_scores_path(trace), params: { value: "1", data_type: "boolean", name: "manual" }
      }.to change(Observ::Score, :count).by(1)

      score = Observ::Score.last
      expect(score.scoreable).to eq(trace)
      expect(score.value).to eq(1.0)
    end

    it "creates a passing score when value is 1" do
      post observ_trace_scores_path(trace), params: { value: "1", data_type: "boolean" }

      score = Observ::Score.last
      expect(score.passed?).to be true
    end

    it "creates a failing score when value is 0" do
      post observ_trace_scores_path(trace), params: { value: "0", data_type: "boolean" }

      score = Observ::Score.last
      expect(score.failed?).to be true
    end

    it "updates existing score instead of creating new one" do
      existing = create(:observ_score, scoreable: trace, name: "manual", source: :manual, value: 1.0)

      expect {
        post observ_trace_scores_path(trace), params: { value: "0", data_type: "boolean", name: "manual" }
      }.not_to change(Observ::Score, :count)

      existing.reload
      expect(existing.value).to eq(0.0)
    end

    it "responds with turbo_stream format" do
      post observ_trace_scores_path(trace), params: { value: "1", data_type: "boolean" }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end
  end

  describe "DELETE /sessions/:session_id/scores/:id" do
    let(:session) { create(:observ_session) }
    let!(:score) { create(:observ_score, scoreable: session, name: "manual", source: :manual) }

    it "destroys the score" do
      expect {
        delete observ_session_score_path(session, score)
      }.to change(Observ::Score, :count).by(-1)
    end

    it "responds with turbo_stream format" do
      delete observ_session_score_path(session, score), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "redirects back with html format" do
      delete observ_session_score_path(session, score)

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to eq("Score deleted.")
    end
  end

  describe "DELETE /traces/:trace_id/scores/:id" do
    let(:trace) { create(:observ_trace) }
    let!(:score) { create(:observ_score, scoreable: trace, name: "manual", source: :manual) }

    it "destroys the score" do
      expect {
        delete observ_trace_score_path(trace, score)
      }.to change(Observ::Score, :count).by(-1)
    end

    it "responds with turbo_stream format" do
      delete observ_trace_score_path(trace, score), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end
  end

  describe "default values" do
    let(:session) { create(:observ_session) }

    it "defaults name to 'manual' when not provided" do
      post observ_session_scores_path(session), params: { value: "1", data_type: "boolean" }

      score = Observ::Score.last
      expect(score.name).to eq("manual")
    end

    it "defaults data_type to boolean when not provided" do
      post observ_session_scores_path(session), params: { value: "1", name: "manual" }

      score = Observ::Score.last
      expect(score.data_type).to eq("boolean")
    end

    it "defaults source to manual" do
      post observ_session_scores_path(session), params: { value: "1" }

      score = Observ::Score.last
      expect(score.source).to eq("manual")
    end
  end
end
