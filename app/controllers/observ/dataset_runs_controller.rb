# frozen_string_literal: true

module Observ
  class DatasetRunsController < ApplicationController
    before_action :set_dataset
    before_action :set_run, only: [ :show, :destroy, :run_evaluators, :review ]

    def index
      @runs = @dataset.runs.order(created_at: :desc)

      if params[:status].present?
        @runs = @runs.where(status: params[:status])
      end

      @runs = @runs.page(params[:page]).per(Observ.config.pagination_per_page)
    end

    def show
      @run_items = @run.run_items
        .includes(:dataset_item, :trace)
        .order(created_at: :asc)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)
    end

    def new
      @run = @dataset.runs.build
    end

    def create
      @run = @dataset.runs.build(run_params)

      if @run.save
        # Initialize run items for all active dataset items
        @run.initialize_run_items!

        # Queue the run for async execution
        Observ::DatasetRunnerJob.perform_later(@run.id)

        redirect_to dataset_run_path(@dataset, @run),
          notice: "Run '#{@run.name}' created with #{@run.total_items} items. Execution will begin shortly."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      name = @run.name
      @run.destroy
      redirect_to dataset_path(@dataset, tab: "runs"),
        notice: "Run '#{name}' deleted successfully."
    end

    def run_evaluators
      evaluator_configs = @dataset.metadata&.dig("evaluators") || [ { "type" => "exact_match" } ]
      Observ::EvaluatorRunnerService.new(@run, evaluator_configs: evaluator_configs).call

      redirect_to dataset_run_path(@dataset, @run),
        notice: "Evaluators completed. #{@run.items_with_scores_count} items scored."
    end

    def review
      @run_item = next_item_to_review(@run)

      if @run_item.nil?
        redirect_to dataset_run_path(@dataset, @run),
          notice: "All items have been reviewed!"
        return
      end

      @progress = review_progress(@run)
      @existing_manual = @run_item.score_for("manual", source: :manual)
    end

    private

    def next_item_to_review(run, after_item: nil)
      items = run.run_items.succeeded.includes(:dataset_item, :scores).order(:id)

      if after_item
        items = items.where("id > ?", after_item.id)
      end

      # Find first item without a manual score
      items.find { |item| item.score_for("manual", source: :manual).nil? } ||
        # If all scored after current, wrap around to find any unscored
        (after_item ? run.run_items.succeeded.includes(:dataset_item, :scores).order(:id).find { |item| item.score_for("manual", source: :manual).nil? } : nil)
    end

    def review_progress(run)
      succeeded_items = run.run_items.succeeded
      total = succeeded_items.count
      scored = succeeded_items.joins(:scores).where(observ_scores: { name: "manual", source: :manual }).distinct.count
      { scored: scored, total: total }
    end

    def set_dataset
      @dataset = Observ::Dataset.find(params[:dataset_id])
    end

    def set_run
      @run = @dataset.runs.find(params[:id])
    end

    def run_params
      # form_with generates param key based on model class name without module prefix
      params.require(:dataset_run).permit(:name, :description)
    end
  end
end
