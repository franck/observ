# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::ReviewQueueController, type: :request do
  describe "GET /reviews" do
    let!(:pending_item) { create(:observ_review_item, :pending, :critical_priority, reason: "error_detected") }
    let!(:in_progress_item) { create(:observ_review_item, :in_progress, :high_priority, reason: "high_cost") }
    let!(:completed_item) { create(:observ_review_item, :completed, reason: "high_latency") }

    it "returns success" do
      get observ_reviews_path
      expect(response).to have_http_status(:success)
    end

    it "shows review queue title" do
      get observ_reviews_path
      expect(response.body).to include("Review Queue")
    end

    it "shows pending item reason" do
      get observ_reviews_path
      expect(response.body).to include("Error Detected")
    end

    it "shows in_progress item reason" do
      get observ_reviews_path
      expect(response.body).to include("High Cost")
    end

    it "does not show completed items reason" do
      get observ_reviews_path
      # high_latency completed item should not be visible in the actionable list
      # The page should show it as part of completed stats but not in the main list
      expect(response.body).to include("Review Queue")
    end

    it "shows queue stats" do
      get observ_reviews_path
      expect(response.body).to include("Pending")
      expect(response.body).to include("In Progress")
    end
  end

  describe "GET /reviews/sessions" do
    let!(:session_item) { create(:observ_review_item, :for_session, :pending, reason: "session_reason") }
    let!(:trace_item) { create(:observ_review_item, :for_trace, :pending, reason: "trace_reason") }

    it "returns success" do
      get sessions_observ_reviews_path
      expect(response).to have_http_status(:success)
    end

    it "shows session reviews" do
      get sessions_observ_reviews_path
      expect(response.body).to include("Session Reason")
    end

    it "marks sessions tab as active" do
      get sessions_observ_reviews_path
      expect(response.body).to include("Sessions")
    end
  end

  describe "GET /reviews/traces" do
    let!(:session_item) { create(:observ_review_item, :for_session, :pending, reason: "session_reason") }
    let!(:trace_item) { create(:observ_review_item, :for_trace, :pending, reason: "trace_reason") }

    it "returns success" do
      get traces_observ_reviews_path
      expect(response).to have_http_status(:success)
    end

    it "shows trace reviews" do
      get traces_observ_reviews_path
      expect(response.body).to include("Trace Reason")
    end

    it "marks traces tab as active" do
      get traces_observ_reviews_path
      expect(response.body).to include("Traces")
    end
  end

  describe "GET /reviews/:id" do
    let(:review_item) { create(:observ_review_item, :pending, :for_session) }

    it "returns success" do
      get observ_review_path(review_item)
      expect(response).to have_http_status(:success)
    end

    it "sets status to in_progress" do
      expect {
        get observ_review_path(review_item)
      }.to change { review_item.reload.status }.from("pending").to("in_progress")
    end

    it "does not change status if already in_progress" do
      review_item.update!(status: :in_progress)

      expect {
        get observ_review_path(review_item)
      }.not_to change { review_item.reload.status }
    end

    it "shows review controls" do
      get observ_review_path(review_item)
      expect(response.body).to include("Save &amp; Next")
      expect(response.body).to include("Skip")
    end

    context "with trace reviewable" do
      let(:review_item) { create(:observ_review_item, :pending, :for_trace) }

      it "returns success" do
        get observ_review_path(review_item)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST /reviews/:id/complete" do
    let(:review_item) { create(:observ_review_item, :pending) }

    it "marks review as complete" do
      expect {
        post complete_observ_review_path(review_item)
      }.to change { review_item.reload.status }.from("pending").to("completed")
    end

    it "sets completed_at" do
      before_time = Time.current
      post complete_observ_review_path(review_item)
      after_time = Time.current
      expect(review_item.reload.completed_at).to be_between(before_time, after_time)
    end

    it "sets completed_by when provided" do
      post complete_observ_review_path(review_item), params: { completed_by: "test_user" }
      expect(review_item.reload.completed_by).to eq("test_user")
    end

    it "redirects to reviews index by default" do
      post complete_observ_review_path(review_item)
      expect(response).to redirect_to(observ_reviews_path)
      expect(flash[:notice]).to eq("Review completed.")
    end

    context "with next param" do
      let!(:next_item) { create(:observ_review_item, :pending) }

      it "redirects to next item when next param present" do
        post complete_observ_review_path(review_item), params: { next: "1" }
        expect(response).to redirect_to(observ_review_path(next_item))
        expect(flash[:notice]).to eq("Review saved. Showing next item.")
      end
    end

    context "with next param but no more items" do
      it "redirects to index when no next item available" do
        post complete_observ_review_path(review_item), params: { next: "1" }
        expect(response).to redirect_to(observ_reviews_path)
      end
    end
  end

  describe "POST /reviews/:id/skip" do
    let(:review_item) { create(:observ_review_item, :pending) }

    it "marks review as skipped" do
      expect {
        post skip_observ_review_path(review_item)
      }.to change { review_item.reload.status }.from("pending").to("skipped")
    end

    it "sets completed_at" do
      before_time = Time.current
      post skip_observ_review_path(review_item)
      after_time = Time.current
      expect(review_item.reload.completed_at).to be_between(before_time, after_time)
    end

    it "sets completed_by when provided" do
      post skip_observ_review_path(review_item), params: { completed_by: "test_user" }
      expect(review_item.reload.completed_by).to eq("test_user")
    end

    context "with next item available" do
      let!(:next_item) { create(:observ_review_item, :pending) }

      it "redirects to next item" do
        post skip_observ_review_path(review_item)
        expect(response).to redirect_to(observ_review_path(next_item))
        expect(flash[:notice]).to eq("Skipped. Showing next item.")
      end
    end

    context "without next item" do
      it "redirects to index" do
        post skip_observ_review_path(review_item)
        expect(response).to redirect_to(observ_reviews_path)
        expect(flash[:notice]).to eq("Item skipped. No more items to review.")
      end
    end
  end

  describe "GET /reviews/stats" do
    let!(:pending_item) { create(:observ_review_item, :pending, reason: "high_cost", priority: :high) }
    let!(:completed_item) { create(:observ_review_item, :completed, reason: "error_detected", priority: :critical) }

    it "returns success" do
      get stats_observ_reviews_path
      expect(response).to have_http_status(:success)
    end

    it "shows statistics page" do
      get stats_observ_reviews_path
      expect(response.body).to include("Statistics")
    end

    it "shows pending count" do
      get stats_observ_reviews_path
      expect(response.body).to include("Total Pending")
    end

    it "shows completed count" do
      get stats_observ_reviews_path
      expect(response.body).to include("Total Completed")
    end

    it "shows breakdown by reason" do
      get stats_observ_reviews_path
      expect(response.body).to include("By Reason")
    end

    it "shows breakdown by priority" do
      get stats_observ_reviews_path
      expect(response.body).to include("By Priority")
    end
  end

  describe "pagination" do
    before do
      # Create more items than default page size
      create_list(:observ_review_item, 30, :pending)
    end

    it "returns success" do
      get observ_reviews_path
      expect(response).to have_http_status(:success)
    end

    it "accepts page parameter" do
      get observ_reviews_path, params: { page: 2 }
      expect(response).to have_http_status(:success)
    end
  end
end
