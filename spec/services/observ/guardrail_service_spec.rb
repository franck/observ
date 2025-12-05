# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::GuardrailService do
  describe ".evaluate_trace" do
    context "with error_detected condition" do
      let(:trace) { create(:observ_trace, metadata: { "error" => "Something went wrong" }) }

      it "enqueues trace for review with critical priority" do
        expect {
          described_class.evaluate_trace(trace)
        }.to change(Observ::ReviewItem, :count).by(1)

        review_item = trace.review_item
        expect(review_item.reason).to eq("error_detected")
        expect(review_item.priority).to eq("critical")
        expect(review_item.reason_details).to eq({ "error" => "Something went wrong" })
      end
    end

    context "with error_span condition" do
      let(:trace) { create(:observ_trace) }
      let!(:error_span) { create(:observ_span, :error, trace: trace) }

      it "enqueues trace for review with critical priority" do
        expect {
          described_class.evaluate_trace(trace)
        }.to change(Observ::ReviewItem, :count).by(1)

        review_item = trace.review_item
        expect(review_item.reason).to eq("error_span")
        expect(review_item.priority).to eq("critical")
      end

      it "includes span details in review item" do
        described_class.evaluate_trace(trace)

        details = trace.review_item.reason_details
        expect(details["span_id"]).to eq(error_span.observation_id)
      end

      it "does not enqueue trace without error spans" do
        normal_trace = create(:observ_trace)
        create(:observ_span, name: "tool:weather", trace: normal_trace)

        expect {
          described_class.evaluate_trace(normal_trace)
        }.not_to change(Observ::ReviewItem, :count)
      end
    end

    context "with high_cost condition" do
      let(:trace) { create(:observ_trace, total_cost: 0.15) }

      it "enqueues trace for review with high priority" do
        expect {
          described_class.evaluate_trace(trace)
        }.to change(Observ::ReviewItem, :count).by(1)

        review_item = trace.review_item
        expect(review_item.reason).to eq("high_cost")
        expect(review_item.priority).to eq("high")
        expect(review_item.reason_details["cost"]).to eq(0.15)
        expect(review_item.reason_details["threshold"]).to eq(0.10)
      end
    end

    context "with high_latency condition" do
      let(:trace) do
        start = Time.current
        create(:observ_trace, start_time: start, end_time: start + 35.seconds)
      end

      it "enqueues trace for review with normal priority" do
        expect {
          described_class.evaluate_trace(trace)
        }.to change(Observ::ReviewItem, :count).by(1)

        review_item = trace.review_item
        expect(review_item.reason).to eq("high_latency")
        expect(review_item.priority).to eq("normal")
        expect(review_item.reason_details["latency_ms"]).to be >= 35000
      end
    end

    context "with no_output condition" do
      let(:trace) { create(:observ_trace, output: nil, end_time: Time.current) }

      it "enqueues trace for review with high priority" do
        expect {
          described_class.evaluate_trace(trace)
        }.to change(Observ::ReviewItem, :count).by(1)

        review_item = trace.review_item
        expect(review_item.reason).to eq("no_output")
        expect(review_item.priority).to eq("high")
      end
    end

    context "with high_token_count condition" do
      let(:trace) { create(:observ_trace, total_tokens: 15000) }

      it "enqueues trace for review with normal priority" do
        expect {
          described_class.evaluate_trace(trace)
        }.to change(Observ::ReviewItem, :count).by(1)

        review_item = trace.review_item
        expect(review_item.reason).to eq("high_token_count")
        expect(review_item.priority).to eq("normal")
        expect(review_item.reason_details["tokens"]).to eq(15000)
      end
    end

    context "when trace is already in review queue" do
      let(:trace) { create(:observ_trace, metadata: { "error" => "Error" }) }
      let!(:existing_review) { create(:observ_review_item, reviewable: trace) }

      it "does not create a new review item" do
        expect {
          described_class.evaluate_trace(trace)
        }.not_to change(Observ::ReviewItem, :count)
      end
    end

    context "when trace does not match any rules" do
      let(:trace) do
        start = Time.current
        create(:observ_trace, total_cost: 0.01, output: "Hello", total_tokens: 100, start_time: start, end_time: start + 1.second)
      end

      it "does not create a review item" do
        expect {
          described_class.evaluate_trace(trace)
        }.not_to change(Observ::ReviewItem, :count)
      end
    end

    context "rule priority (stops after first match)" do
      let(:trace) { create(:observ_trace, metadata: { "error" => "Error" }, total_cost: 0.15) }

      it "only creates one review item with first matching rule" do
        described_class.evaluate_trace(trace)

        expect(Observ::ReviewItem.where(reviewable: trace).count).to eq(1)
        expect(trace.review_item.reason).to eq("error_detected")
      end
    end
  end

  describe ".evaluate_session" do
    context "with high_cost condition" do
      let(:session) { create(:observ_session, total_cost: 0.60) }

      it "enqueues session for review with high priority" do
        expect {
          described_class.evaluate_session(session)
        }.to change(Observ::ReviewItem, :count).by(1)

        review_item = session.review_item
        expect(review_item.reason).to eq("high_cost")
        expect(review_item.priority).to eq("high")
        expect(review_item.reason_details["cost"]).to eq(0.60)
        expect(review_item.reason_details["threshold"]).to eq(0.50)
      end
    end


    context "with many_traces condition" do
      let(:session) { create(:observ_session, total_traces_count: 25) }

      it "enqueues session for review with normal priority" do
        expect {
          described_class.evaluate_session(session)
        }.to change(Observ::ReviewItem, :count).by(1)

        review_item = session.review_item
        expect(review_item.reason).to eq("many_traces")
        expect(review_item.priority).to eq("normal")
        expect(review_item.reason_details["trace_count"]).to eq(25)
      end
    end

    context "when session is already in review queue" do
      let(:session) { create(:observ_session, total_cost: 0.60) }
      let!(:existing_review) { create(:observ_review_item, reviewable: session) }

      it "does not create a new review item" do
        expect {
          described_class.evaluate_session(session)
        }.not_to change(Observ::ReviewItem, :count)
      end
    end

    context "when session does not match any rules" do
      let(:session) { create(:observ_session, total_cost: 0.01, total_traces_count: 5) }

      it "does not create a review item" do
        expect {
          described_class.evaluate_session(session)
        }.not_to change(Observ::ReviewItem, :count)
      end
    end
  end

  describe ".evaluate_all_recent" do
    let!(:error_trace) { create(:observ_trace, metadata: { "error" => "Error" }, created_at: 30.minutes.ago) }
    let!(:high_cost_session) { create(:observ_session, total_cost: 0.60, created_at: 30.minutes.ago) }
    let!(:old_trace) { create(:observ_trace, metadata: { "error" => "Old error" }, created_at: 2.hours.ago) }
    let!(:normal_trace) { create(:observ_trace, created_at: 30.minutes.ago) }

    it "evaluates all recent traces and sessions" do
      expect {
        described_class.evaluate_all_recent(since: 1.hour.ago)
      }.to change(Observ::ReviewItem, :count).by(2)

      expect(error_trace.reload.in_review_queue?).to be true
      expect(high_cost_session.reload.in_review_queue?).to be true
    end

    it "does not evaluate items older than since" do
      described_class.evaluate_all_recent(since: 1.hour.ago)
      expect(old_trace.reload.in_review_queue?).to be false
    end

    it "does not re-evaluate items already in queue" do
      create(:observ_review_item, reviewable: error_trace)

      expect {
        described_class.evaluate_all_recent(since: 1.hour.ago)
      }.to change(Observ::ReviewItem, :count).by(1) # Only high_cost_session
    end
  end

  describe ".random_sample" do
    let!(:session1) { create(:observ_session, created_at: 12.hours.ago) }
    let!(:session2) { create(:observ_session, created_at: 12.hours.ago) }
    let!(:session3) { create(:observ_session, created_at: 12.hours.ago) }
    let!(:old_session) { create(:observ_session, created_at: 2.days.ago) }
    let!(:queued_session) { create(:observ_session, created_at: 12.hours.ago) }

    before do
      create(:observ_review_item, reviewable: queued_session)
    end

    it "creates review items for random sample of recent items" do
      expect {
        described_class.random_sample(scope: Observ::Session, percentage: 50)
      }.to change(Observ::ReviewItem, :count)
    end

    it "sets reason to random_sample" do
      described_class.random_sample(scope: Observ::Session, percentage: 100)

      review_items = Observ::ReviewItem.where(reason: "random_sample")
      expect(review_items.count).to be >= 1
    end

    it "does not include items older than 1 day" do
      described_class.random_sample(scope: Observ::Session, percentage: 100)

      expect(old_session.reload.in_review_queue?).to be false
    end

    it "does not include items already in review queue" do
      described_class.random_sample(scope: Observ::Session, percentage: 100)

      # queued_session should still only have one review item
      expect(Observ::ReviewItem.where(reviewable: queued_session).count).to eq(1)
    end

    it "creates at least 1 item even with small percentage" do
      expect {
        described_class.random_sample(scope: Observ::Session, percentage: 1)
      }.to change(Observ::ReviewItem, :count).by_at_least(1)
    end

    it "works with Trace scope" do
      trace1 = create(:observ_trace, created_at: 12.hours.ago)
      trace2 = create(:observ_trace, created_at: 12.hours.ago)

      expect {
        described_class.random_sample(scope: Observ::Trace, percentage: 100)
      }.to change(Observ::ReviewItem, :count).by(2)

      expect(trace1.reload.in_review_queue?).to be true
      expect(trace2.reload.in_review_queue?).to be true
    end
  end
end
