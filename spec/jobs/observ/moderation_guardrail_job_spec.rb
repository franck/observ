# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::ModerationGuardrailJob, type: :job do
  let(:session) { create(:observ_session) }
  let(:trace) { create(:observ_trace, observ_session: session, input: "Test content") }

  let(:safe_result) do
    double(
      "ModerationResult",
      flagged?: false,
      flagged_categories: [],
      category_scores: { "hate" => 0.01 },
      categories: {},
      model: "omni-moderation-latest",
      id: "test-id"
    )
  end

  before do
    allow(RubyLLM).to receive(:moderate).and_return(safe_result)
  end

  describe "#perform" do
    context "with trace_id" do
      it "moderates the trace" do
        expect(RubyLLM).to receive(:moderate)
        described_class.perform_now(trace_id: trace.id)
      end

      it "calls the service with correct options" do
        service = instance_double(Observ::ModerationGuardrailService)
        allow(Observ::ModerationGuardrailService).to receive(:new).and_return(service)
        allow(service).to receive(:evaluate_trace).and_return(
          Observ::ModerationGuardrailService::Result.new(action: :passed)
        )

        described_class.perform_now(trace_id: trace.id, moderate_input: false, moderate_output: true)

        expect(service).to have_received(:evaluate_trace).with(
          trace,
          moderate_input: false,
          moderate_output: true
        )
      end
    end

    context "with session_id" do
      before do
        create_list(:observ_trace, 3, observ_session: session, input: "Test")
      end

      it "moderates all traces in session" do
        expect(RubyLLM).to receive(:moderate).exactly(3).times
        described_class.perform_now(session_id: session.id)
      end
    end

    context "with session_id and aggregate option" do
      before do
        create_list(:observ_trace, 3, observ_session: session, input: "Test")
      end

      it "moderates aggregated content" do
        expect(RubyLLM).to receive(:moderate).once
        described_class.perform_now(session_id: session.id, aggregate: true)
      end
    end

    context "with neither trace_id nor session_id" do
      it "logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/No trace_id or session_id provided/)
        described_class.perform_now
      end
    end

    context "with missing record" do
      it "discards the job for missing trace" do
        expect {
          described_class.perform_now(trace_id: 999999)
        }.not_to raise_error
      end

      it "discards the job for missing session" do
        expect {
          described_class.perform_now(session_id: 999999)
        }.not_to raise_error
      end
    end
  end

  describe ".enqueue_for_scope" do
    before do
      create_list(:observ_trace, 5, observ_session: session, input: "Test")
    end

    it "enqueues jobs for all traces in scope" do
      expect {
        described_class.enqueue_for_scope(Observ::Trace.all)
      }.to have_enqueued_job(described_class).exactly(5).times
    end

    it "samples traces when sample_percentage is provided" do
      expect {
        described_class.enqueue_for_scope(Observ::Trace.all, sample_percentage: 50)
      }.to have_enqueued_job(described_class).at_least(2).times
    end

    it "excludes traces already in review queue" do
      Observ::Trace.first.enqueue_for_review!(reason: "test", priority: :normal)

      expect {
        described_class.enqueue_for_scope(Observ::Trace.all)
      }.to have_enqueued_job(described_class).exactly(4).times
    end
  end

  describe ".enqueue_user_facing" do
    before do
      create(:observ_session, metadata: { "user_facing" => "true" })
      create(:observ_session, metadata: { "user_facing" => "false" })
      create(:observ_session, metadata: {})
    end

    it "only enqueues user-facing sessions" do
      expect {
        described_class.enqueue_user_facing
      }.to have_enqueued_job(described_class).exactly(1).times
    end

    it "respects the since parameter" do
      old_session = create(:observ_session, metadata: { "user_facing" => "true" }, created_at: 2.hours.ago)

      expect {
        described_class.enqueue_user_facing(since: 1.hour.ago)
      }.to have_enqueued_job(described_class).exactly(1).times
    end
  end

  describe ".enqueue_for_agent_types" do
    before do
      create(:observ_session, metadata: { "agent_type" => "chat_support" })
      create(:observ_session, metadata: { "agent_type" => "internal_tool" })
      create(:observ_session, metadata: { "agent_type" => "chat_support" })
    end

    it "enqueues sessions matching agent types" do
      expect {
        described_class.enqueue_for_agent_types([ "chat_support" ])
      }.to have_enqueued_job(described_class).exactly(2).times
    end

    it "respects the since parameter" do
      create(:observ_session, metadata: { "agent_type" => "chat_support" }, created_at: 2.hours.ago)

      expect {
        described_class.enqueue_for_agent_types([ "chat_support" ], since: 1.hour.ago)
      }.to have_enqueued_job(described_class).exactly(2).times
    end
  end

  describe "job configuration" do
    it "is queued in the moderation queue" do
      expect(described_class.new.queue_name).to eq("moderation")
    end

    it "can be enqueued" do
      expect {
        described_class.perform_later(trace_id: trace.id)
      }.to have_enqueued_job(described_class).with(trace_id: trace.id)
    end

    it "is configured to retry on StandardError" do
      handlers = described_class.rescue_handlers.map { |h| h[0] }
      expect(handlers).to include("StandardError")
    end

    it "is configured to discard on ActiveRecord::RecordNotFound" do
      # Check discard_on configuration
      expect(described_class.rescue_handlers.any? { |h| h[0] == "ActiveRecord::RecordNotFound" }).to be true
    end
  end
end
