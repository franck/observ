# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::ModerationGuardrailService do
  let(:session) { create(:observ_session) }
  let(:trace) { create(:observ_trace, observ_session: session, input: "Hello world", output: "Hi there!") }
  let(:service) { described_class.new }

  let(:safe_moderation_result) do
    double(
      "ModerationResult",
      flagged?: false,
      flagged_categories: [],
      category_scores: { "hate" => 0.01, "violence" => 0.02 },
      categories: {},
      model: "omni-moderation-latest",
      id: "test-id"
    )
  end

  let(:flagged_moderation_result) do
    double(
      "ModerationResult",
      flagged?: true,
      flagged_categories: ["hate", "harassment"],
      category_scores: { "hate" => 0.95, "harassment" => 0.87, "violence" => 0.1 },
      categories: { "hate" => true, "harassment" => true },
      model: "omni-moderation-latest",
      id: "test-id"
    )
  end

  let(:high_score_result) do
    double(
      "ModerationResult",
      flagged?: false,
      flagged_categories: [],
      category_scores: { "hate" => 0.75, "violence" => 0.2 },
      categories: {},
      model: "omni-moderation-latest",
      id: "test-id"
    )
  end

  before do
    allow(RubyLLM).to receive(:moderate).and_return(safe_moderation_result)
  end

  describe "#evaluate_trace" do
    context "when trace is already in review queue" do
      before do
        trace.enqueue_for_review!(reason: "test", priority: :normal)
      end

      it "returns skipped result" do
        result = service.evaluate_trace(trace)
        expect(result.skipped?).to be true
        expect(result.reason).to eq("already_in_queue")
      end
    end

    context "when trace already has flagged moderations" do
      before do
        moderation = trace.create_moderation(name: "moderation")
        moderation.update!(metadata: { "flagged" => true })
      end

      it "returns skipped result" do
        result = service.evaluate_trace(trace)
        expect(result.skipped?).to be true
        expect(result.reason).to eq("already_has_moderation")
      end
    end

    context "when trace has no content" do
      let(:trace) { create(:observ_trace, observ_session: session, input: nil, output: nil) }

      it "returns skipped result" do
        result = service.evaluate_trace(trace)
        expect(result.skipped?).to be true
        expect(result.reason).to eq("no_content")
      end
    end

    context "when content passes moderation" do
      it "returns passed result" do
        result = service.evaluate_trace(trace)
        expect(result.passed?).to be true
      end

      it "does not enqueue for review" do
        expect { service.evaluate_trace(trace) }.not_to change { trace.reload.in_review_queue? }
      end
    end

    context "when content is flagged" do
      before do
        allow(RubyLLM).to receive(:moderate).and_return(flagged_moderation_result)
      end

      it "returns flagged result" do
        result = service.evaluate_trace(trace)
        expect(result.flagged?).to be true
      end

      it "enqueues trace for review" do
        service.evaluate_trace(trace)
        expect(trace.reload.in_review_queue?).to be true
      end

      it "sets correct priority" do
        result = service.evaluate_trace(trace)
        expect(result.priority).to eq(:critical)
      end

      it "includes flagged categories in details" do
        result = service.evaluate_trace(trace)
        expect(result.details[:flagged_categories]).to eq(["hate", "harassment"])
      end

      it "sets review item reason to content_moderation" do
        service.evaluate_trace(trace)
        expect(trace.review_item.reason).to eq("content_moderation")
      end
    end

    context "when content has high scores but not flagged" do
      before do
        allow(RubyLLM).to receive(:moderate).and_return(high_score_result)
      end

      it "returns flagged result with high priority" do
        result = service.evaluate_trace(trace)
        expect(result.flagged?).to be true
        expect(result.priority).to eq(:high)
      end
    end

    context "with critical categories" do
      let(:critical_result) do
        double(
          "ModerationResult",
          flagged?: true,
          flagged_categories: ["sexual/minors"],
          category_scores: { "sexual/minors" => 0.99 },
          categories: { "sexual/minors" => true },
          model: "omni-moderation-latest",
          id: "test-id"
        )
      end

      before do
        allow(RubyLLM).to receive(:moderate).and_return(critical_result)
      end

      it "sets critical priority" do
        result = service.evaluate_trace(trace)
        expect(result.priority).to eq(:critical)
      end
    end

    context "with moderate_input and moderate_output options" do
      it "only moderates input when moderate_output is false" do
        service.evaluate_trace(trace, moderate_input: true, moderate_output: false)
        expect(RubyLLM).to have_received(:moderate).with("Hello world")
      end

      it "only moderates output when moderate_input is false" do
        service.evaluate_trace(trace, moderate_input: false, moderate_output: true)
        expect(RubyLLM).to have_received(:moderate).with("Hi there!")
      end
    end

    context "when an error occurs" do
      before do
        allow(RubyLLM).to receive(:moderate).and_raise(StandardError, "API error")
      end

      it "returns skipped result with error" do
        result = service.evaluate_trace(trace)
        expect(result.skipped?).to be true
        expect(result.reason).to eq("error")
        expect(result.details[:error]).to eq("API error")
      end
    end
  end

  describe "#evaluate_session" do
    let!(:trace1) { create(:observ_trace, observ_session: session, input: "First message") }
    let!(:trace2) { create(:observ_trace, observ_session: session, input: "Second message") }

    it "evaluates all traces in session" do
      results = service.evaluate_session(session)
      expect(results.size).to eq(2)
    end

    it "returns results for each trace" do
      results = service.evaluate_session(session)
      expect(results.all?(&:passed?)).to be true
    end

    context "with empty session" do
      let(:empty_session) { create(:observ_session) }

      it "returns empty array" do
        results = service.evaluate_session(empty_session)
        expect(results).to eq([])
      end
    end
  end

  describe "#evaluate_session_content" do
    before do
      create(:observ_trace, observ_session: session, input: "Message 1", output: "Response 1")
      create(:observ_trace, observ_session: session, input: "Message 2", output: "Response 2")
    end

    it "moderates aggregated session content" do
      service.evaluate_session_content(session)
      expect(RubyLLM).to have_received(:moderate) do |content|
        expect(content).to include("Message 1")
        expect(content).to include("Response 2")
      end
    end

    context "when session is already in review queue" do
      before do
        session.enqueue_for_review!(reason: "test", priority: :normal)
      end

      it "returns skipped result" do
        result = service.evaluate_session_content(session)
        expect(result.skipped?).to be true
        expect(result.reason).to eq("already_in_queue")
      end
    end

    context "when content is flagged" do
      before do
        allow(RubyLLM).to receive(:moderate).and_return(flagged_moderation_result)
      end

      it "enqueues session for review" do
        service.evaluate_session_content(session)
        expect(session.reload.in_review_queue?).to be true
      end

      it "sets review item reason to content_moderation" do
        service.evaluate_session_content(session)
        expect(session.review_item.reason).to eq("content_moderation")
      end
    end
  end

  describe "Result class" do
    it "supports flagged?" do
      result = described_class::Result.new(action: :flagged)
      expect(result.flagged?).to be true
      expect(result.skipped?).to be false
      expect(result.passed?).to be false
    end

    it "supports skipped?" do
      result = described_class::Result.new(action: :skipped, reason: "test")
      expect(result.skipped?).to be true
      expect(result.flagged?).to be false
      expect(result.passed?).to be false
    end

    it "supports passed?" do
      result = described_class::Result.new(action: :passed)
      expect(result.passed?).to be true
      expect(result.flagged?).to be false
      expect(result.skipped?).to be false
    end
  end

  describe "priority determination" do
    context "when score is above critical threshold" do
      let(:critical_score_result) do
        double(
          "ModerationResult",
          flagged?: true,
          flagged_categories: ["hate"],
          category_scores: { "hate" => 0.95 },
          categories: { "hate" => true },
          model: "omni-moderation-latest",
          id: "test-id"
        )
      end

      before do
        allow(RubyLLM).to receive(:moderate).and_return(critical_score_result)
      end

      it "sets critical priority" do
        result = service.evaluate_trace(trace)
        expect(result.priority).to eq(:critical)
      end
    end

    context "when score is above review threshold but below high" do
      let(:normal_priority_result) do
        double(
          "ModerationResult",
          flagged?: false,
          flagged_categories: [],
          category_scores: { "hate" => 0.55 },
          categories: {},
          model: "omni-moderation-latest",
          id: "test-id"
        )
      end

      before do
        allow(RubyLLM).to receive(:moderate).and_return(normal_priority_result)
      end

      it "sets normal priority" do
        result = service.evaluate_trace(trace)
        expect(result.priority).to eq(:normal)
      end
    end

    context "when score is below review threshold" do
      let(:low_score_result) do
        double(
          "ModerationResult",
          flagged?: false,
          flagged_categories: [],
          category_scores: { "hate" => 0.3 },
          categories: {},
          model: "omni-moderation-latest",
          id: "test-id"
        )
      end

      before do
        allow(RubyLLM).to receive(:moderate).and_return(low_score_result)
      end

      it "returns passed (no priority)" do
        result = service.evaluate_trace(trace)
        expect(result.passed?).to be true
        expect(result.priority).to be_nil
      end
    end
  end

  describe "content extraction" do
    context "with hash input containing text key" do
      let(:trace) { create(:observ_trace, observ_session: session, input: { "text" => "Hello" }.to_json) }

      before do
        allow(trace).to receive(:input).and_return({ "text" => "Hello" })
      end

      it "extracts text from hash" do
        service.evaluate_trace(trace)
        expect(RubyLLM).to have_received(:moderate).with("Hello")
      end
    end
  end
end
