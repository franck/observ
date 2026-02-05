# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::ReviewItem, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:reviewable) }
  end

  describe "validations" do
    subject { build(:observ_review_item) }

    it { is_expected.to validate_presence_of(:reviewable) }

    it "validates uniqueness of reviewable_id scoped to reviewable_type" do
      existing = create(:observ_review_item, :for_session)
      duplicate = build(:observ_review_item, reviewable: existing.reviewable)
      expect(duplicate).not_to be_valid
    end

    it "allows same reviewable_id with different reviewable_type" do
      session = create(:observ_session)
      trace = create(:observ_trace)
      create(:observ_review_item, reviewable: session)
      different_type = build(:observ_review_item, reviewable: trace)
      expect(different_type).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, in_progress: 1, completed: 2, skipped: 3) }
    it { is_expected.to define_enum_for(:priority).with_values(normal: 0, high: 1, critical: 2) }
  end

  describe "scopes" do
    let!(:pending_item) { create(:observ_review_item, :pending) }
    let!(:in_progress_item) { create(:observ_review_item, :in_progress) }
    let!(:completed_item) { create(:observ_review_item, :completed) }
    let!(:skipped_item) { create(:observ_review_item, :skipped) }
    let!(:session_item) { create(:observ_review_item, :for_session, :pending) }
    let!(:trace_item) { create(:observ_review_item, :for_trace, :pending) }

    describe ".actionable" do
      it "returns pending and in_progress items" do
        expect(described_class.actionable).to include(pending_item, in_progress_item, session_item, trace_item)
        expect(described_class.actionable).not_to include(completed_item, skipped_item)
      end
    end

    describe ".by_priority" do
      let!(:critical_item) { create(:observ_review_item, :critical_priority) }
      let!(:high_item) { create(:observ_review_item, :high_priority) }
      let!(:normal_item) { create(:observ_review_item, :normal_priority) }

      it "orders by priority desc, created_at asc" do
        items = described_class.by_priority.where(id: [critical_item.id, high_item.id, normal_item.id])
        expect(items.first).to eq(critical_item)
        expect(items.second).to eq(high_item)
        expect(items.third).to eq(normal_item)
      end
    end

    describe ".sessions" do
      it "returns only session reviews" do
        expect(described_class.sessions).to include(session_item)
        expect(described_class.sessions).not_to include(trace_item)
      end
    end

    describe ".traces" do
      it "returns only trace reviews" do
        expect(described_class.traces).to include(trace_item)
        expect(described_class.traces).not_to include(session_item)
      end
    end
  end

  describe "#complete!" do
    let(:review_item) { create(:observ_review_item, :pending) }

    it "sets status to completed" do
      review_item.complete!
      expect(review_item.reload.status).to eq("completed")
    end

    it "sets completed_at" do
      before_time = Time.current
      review_item.complete!
      after_time = Time.current
      expect(review_item.reload.completed_at).to be_between(before_time, after_time)
    end

    it "sets completed_by when provided" do
      review_item.complete!(by: "test_user")
      expect(review_item.reload.completed_by).to eq("test_user")
    end
  end

  describe "#skip!" do
    let(:review_item) { create(:observ_review_item, :pending) }

    it "sets status to skipped" do
      review_item.skip!
      expect(review_item.reload.status).to eq("skipped")
    end

    it "sets completed_at" do
      before_time = Time.current
      review_item.skip!
      after_time = Time.current
      expect(review_item.reload.completed_at).to be_between(before_time, after_time)
    end

    it "sets completed_by when provided" do
      review_item.skip!(by: "test_user")
      expect(review_item.reload.completed_by).to eq("test_user")
    end
  end

  describe "#start_review!" do
    context "when pending" do
      let(:review_item) { create(:observ_review_item, :pending) }

      it "sets status to in_progress" do
        review_item.start_review!
        expect(review_item.reload.status).to eq("in_progress")
      end
    end

    context "when not pending" do
      let(:review_item) { create(:observ_review_item, :in_progress) }

      it "does not change status" do
        review_item.start_review!
        expect(review_item.reload.status).to eq("in_progress")
      end
    end

    context "when completed" do
      let(:review_item) { create(:observ_review_item, :completed) }

      it "does not change status" do
        review_item.start_review!
        expect(review_item.reload.status).to eq("completed")
      end
    end
  end

  describe "#priority_badge_class" do
    it "returns danger class for critical priority" do
      item = build(:observ_review_item, :critical_priority)
      expect(item.priority_badge_class).to eq("observ-badge--danger")
    end

    it "returns warning class for high priority" do
      item = build(:observ_review_item, :high_priority)
      expect(item.priority_badge_class).to eq("observ-badge--warning")
    end

    it "returns secondary class for normal priority" do
      item = build(:observ_review_item, :normal_priority)
      expect(item.priority_badge_class).to eq("observ-badge--secondary")
    end
  end

  describe "#reason_display" do
    it "returns titleized reason" do
      item = build(:observ_review_item, reason: "high_cost")
      expect(item.reason_display).to eq("High Cost")
    end

    it "returns 'Manual' when reason is nil" do
      item = build(:observ_review_item, reason: nil)
      expect(item.reason_display).to eq("Manual")
    end

    it "handles underscores in reason" do
      item = build(:observ_review_item, reason: "error_detected")
      expect(item.reason_display).to eq("Error Detected")
    end
  end

  describe "#reviewable_type_display" do
    it "returns demodulized class name for Session" do
      item = build(:observ_review_item, :for_session)
      expect(item.reviewable_type_display).to eq("Session")
    end

    it "returns demodulized class name for Trace" do
      item = build(:observ_review_item, :for_trace)
      expect(item.reviewable_type_display).to eq("Trace")
    end
  end
end
