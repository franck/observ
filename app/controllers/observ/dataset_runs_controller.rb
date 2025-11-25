# frozen_string_literal: true

module Observ
  class DatasetRunsController < ApplicationController
    before_action :set_dataset
    before_action :set_run, only: [ :show, :destroy ]

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

        # Queue the run for async execution (Phase 3)
        # Observ::DatasetRunnerJob.perform_later(@run.id)

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

    private

    def set_dataset
      @dataset = Observ::Dataset.find(params[:dataset_id])
    end

    def set_run
      @run = @dataset.runs.find(params[:id])
    end

    def run_params
      params.require(:observ_dataset_run).permit(:name, :description)
    end
  end
end
