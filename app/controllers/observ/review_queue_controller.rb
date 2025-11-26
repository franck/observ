# frozen_string_literal: true

module Observ
  class ReviewQueueController < ApplicationController
    before_action :set_review_item, only: [ :show, :complete, :skip ]

    def index
      @review_items = Observ::ReviewItem
        .actionable
        .by_priority
        .includes(:reviewable)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)

      @stats = queue_stats
      @filter = :all
    end

    def sessions
      @review_items = Observ::ReviewItem
        .sessions
        .actionable
        .by_priority
        .includes(:reviewable)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)

      @stats = queue_stats(scope: :sessions)
      @filter = :sessions
      render :index
    end

    def traces
      @review_items = Observ::ReviewItem
        .traces
        .actionable
        .by_priority
        .includes(:reviewable)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)

      @stats = queue_stats(scope: :traces)
      @filter = :traces
      render :index
    end

    def show
      @review_item.start_review!
      @reviewable = @review_item.reviewable
      @next_item = next_review_item
      @queue_position = queue_position

      # Load additional data for sessions
      if @reviewable.is_a?(Observ::Session)
        @session_metrics = @reviewable.session_metrics
        @traces = @reviewable.traces.includes(:observations).order(start_time: :asc).limit(10)
        @chat = @reviewable.chat if defined?(::Chat)
      elsif @reviewable.is_a?(Observ::Trace)
        @observations = @reviewable.observations.order(start_time: :asc).limit(5)
      end
    end

    def complete
      @review_item.complete!(by: params[:completed_by])

      if params[:next] && (next_item = next_review_item)
        redirect_to review_path(next_item), notice: "Review saved. Showing next item."
      else
        redirect_to reviews_path, notice: "Review completed."
      end
    end

    def skip
      @review_item.skip!(by: params[:completed_by])

      if (next_item = next_review_item)
        redirect_to review_path(next_item), notice: "Skipped. Showing next item."
      else
        redirect_to reviews_path, notice: "Item skipped. No more items to review."
      end
    end

    def stats
      @stats = detailed_stats
    end

    private

    def set_review_item
      @review_item = Observ::ReviewItem.find(params[:id])
    end

    def next_review_item
      Observ::ReviewItem
        .actionable
        .by_priority
        .where.not(id: @review_item&.id)
        .first
    end

    def queue_position
      return nil unless @review_item

      # Convert enum string to integer for SQL comparison
      priority_value = Observ::ReviewItem.priorities[@review_item.priority]

      {
        current: Observ::ReviewItem.actionable.where(
          "priority > :priority OR (priority = :priority AND created_at < :created_at)",
          priority: priority_value,
          created_at: @review_item.created_at
        ).count + 1,
        total: Observ::ReviewItem.actionable.count
      }
    end

    def queue_stats(scope: nil)
      base = Observ::ReviewItem
      base = base.send(scope) if scope

      {
        pending: base.pending.count,
        in_progress: base.in_progress.count,
        completed_today: base.completed.where("completed_at >= ?", Time.current.beginning_of_day).count,
        completed_this_week: base.completed.where("completed_at >= ?", Time.current.beginning_of_week).count
      }
    end

    def detailed_stats
      completed = Observ::ReviewItem.completed

      {
        total_pending: Observ::ReviewItem.actionable.count,
        total_completed: completed.count,
        completed_today: completed.where("completed_at >= ?", Time.current.beginning_of_day).count,
        completed_this_week: completed.where("completed_at >= ?", Time.current.beginning_of_week).count,
        by_reason: Observ::ReviewItem.group(:reason).count,
        by_priority: Observ::ReviewItem.group(:priority).count,
        pass_rate: calculate_pass_rate
      }
    end

    def calculate_pass_rate
      completed_items = Observ::ReviewItem.completed.includes(:reviewable)
      return nil if completed_items.empty?

      passed = completed_items.count do |item|
        item.reviewable&.manual_score&.passed?
      end

      (passed.to_f / completed_items.count * 100).round(1)
    end
  end
end
