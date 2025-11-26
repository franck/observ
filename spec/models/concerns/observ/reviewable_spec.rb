# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Reviewable do
  # Test with Session as the concrete class
  let(:reviewable) { create(:observ_session) }

  describe "associations" do
    it "has one review_item" do
      expect(reviewable).to respond_to(:review_item)
    end

    it "destroys review_item when reviewable is destroyed" do
      create(:observ_review_item, reviewable: reviewable)
      expect { reviewable.destroy }.to change(Observ::ReviewItem, :count).by(-1)
    end
  end

  describe "#enqueue_for_review!" do
    context "when not already queued" do
      it "creates a new review item" do
        expect {
          reviewable.enqueue_for_review!(reason: "high_cost", priority: :high)
        }.to change(Observ::ReviewItem, :count).by(1)
      end

      it "creates review item with correct attributes" do
        review_item = reviewable.enqueue_for_review!(
          reason: "high_cost",
          priority: :high,
          details: { cost: 0.15, threshold: 0.10 }
        )

        expect(review_item.reason).to eq("high_cost")
        expect(review_item.priority).to eq("high")
        expect(review_item.reason_details).to eq({ "cost" => 0.15, "threshold" => 0.10 })
        expect(review_item.status).to eq("pending")
        expect(review_item.reviewable).to eq(reviewable)
      end

      it "defaults priority to normal" do
        review_item = reviewable.enqueue_for_review!(reason: "test")
        expect(review_item.priority).to eq("normal")
      end

      it "defaults details to empty hash" do
        review_item = reviewable.enqueue_for_review!(reason: "test")
        expect(review_item.reason_details).to eq({})
      end
    end

    context "when already queued" do
      let!(:existing_review_item) { create(:observ_review_item, reviewable: reviewable) }

      it "returns existing review item" do
        result = reviewable.enqueue_for_review!(reason: "different_reason", priority: :critical)
        expect(result).to eq(existing_review_item)
      end

      it "does not create a new review item" do
        expect {
          reviewable.enqueue_for_review!(reason: "different_reason")
        }.not_to change(Observ::ReviewItem, :count)
      end
    end
  end

  describe "#review_status" do
    context "when queued" do
      it "returns status of review item" do
        create(:observ_review_item, :pending, reviewable: reviewable)
        expect(reviewable.review_status).to eq("pending")
      end

      it "returns in_progress when in progress" do
        create(:observ_review_item, :in_progress, reviewable: reviewable)
        expect(reviewable.review_status).to eq("in_progress")
      end

      it "returns completed when completed" do
        create(:observ_review_item, :completed, reviewable: reviewable)
        expect(reviewable.review_status).to eq("completed")
      end
    end

    context "when not queued" do
      it "returns 'not_queued'" do
        expect(reviewable.review_status).to eq("not_queued")
      end
    end
  end

  describe "#reviewed?" do
    it "returns true when review is completed" do
      create(:observ_review_item, :completed, reviewable: reviewable)
      expect(reviewable.reviewed?).to be true
    end

    it "returns false when review is pending" do
      create(:observ_review_item, :pending, reviewable: reviewable)
      expect(reviewable.reviewed?).to be false
    end

    it "returns false when review is in_progress" do
      create(:observ_review_item, :in_progress, reviewable: reviewable)
      expect(reviewable.reviewed?).to be false
    end

    it "returns falsy value when not queued" do
      expect(reviewable.reviewed?).to be_falsy
    end
  end

  describe "#pending_review?" do
    it "returns true when review is pending" do
      create(:observ_review_item, :pending, reviewable: reviewable)
      expect(reviewable.pending_review?).to be true
    end

    it "returns true when review is in_progress" do
      create(:observ_review_item, :in_progress, reviewable: reviewable)
      expect(reviewable.pending_review?).to be true
    end

    it "returns false when review is completed" do
      create(:observ_review_item, :completed, reviewable: reviewable)
      expect(reviewable.pending_review?).to be false
    end

    it "returns falsy value when not queued" do
      expect(reviewable.pending_review?).to be_falsy
    end
  end

  describe "#in_review_queue?" do
    it "returns true when review_item exists" do
      create(:observ_review_item, reviewable: reviewable)
      expect(reviewable.in_review_queue?).to be true
    end

    it "returns false when no review_item exists" do
      expect(reviewable.in_review_queue?).to be false
    end

    it "returns true even when review is completed" do
      create(:observ_review_item, :completed, reviewable: reviewable)
      expect(reviewable.in_review_queue?).to be true
    end
  end

  describe "inclusion in models" do
    it "is included in Session" do
      session = Observ::Session.new
      expect(session).to respond_to(:review_item)
      expect(session).to respond_to(:enqueue_for_review!)
      expect(session).to respond_to(:review_status)
      expect(session).to respond_to(:reviewed?)
      expect(session).to respond_to(:pending_review?)
      expect(session).to respond_to(:in_review_queue?)
    end

    it "is included in Trace" do
      trace = Observ::Trace.new
      expect(trace).to respond_to(:review_item)
      expect(trace).to respond_to(:enqueue_for_review!)
      expect(trace).to respond_to(:review_status)
      expect(trace).to respond_to(:reviewed?)
      expect(trace).to respond_to(:pending_review?)
      expect(trace).to respond_to(:in_review_queue?)
    end
  end
end
