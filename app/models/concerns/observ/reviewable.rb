# frozen_string_literal: true

module Observ
  module Reviewable
    extend ActiveSupport::Concern

    included do
      has_one :review_item, as: :reviewable, class_name: "Observ::ReviewItem", dependent: :destroy
    end

    # Enqueue this item for review, or return existing review_item if already queued
    def enqueue_for_review!(reason:, priority: :normal, details: {})
      review_item || create_review_item!(
        reason: reason.to_s,
        reason_details: details,
        priority: priority,
        status: :pending
      )
    end

    # Returns the review status or 'not_queued' if not in queue
    def review_status
      review_item&.status || "not_queued"
    end

    # Returns true if review has been completed
    def reviewed?
      review_item&.completed?
    end

    # Returns true if review is pending or in progress
    def pending_review?
      review_item&.pending? || review_item&.in_progress?
    end

    # Returns true if this item is in the review queue
    def in_review_queue?
      review_item.present?
    end
  end
end
