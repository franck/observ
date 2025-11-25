# frozen_string_literal: true

module Observ
  class DatasetRunItemsController < ApplicationController
    before_action :set_dataset
    before_action :set_run
    before_action :set_run_item

    def details_drawer
      # The drawer template will use @run_item
    end

    def score_drawer
      # Renders the score drawer partial
    end

    def score
      value = params[:value].to_i == 1 ? 1.0 : 0.0

      score = @run_item.scores.find_or_initialize_by(name: "manual", source: :manual)
      score.assign_attributes(
        trace: @run_item.trace,
        value: value,
        data_type: :boolean,
        comment: params[:comment],
        created_by: params[:created_by]
      )

      if score.save
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace("run-item-#{@run_item.id}-scores",
                partial: "observ/dataset_run_items/scores_cell",
                locals: { run_item: @run_item }),
              turbo_stream.update("drawer-content",
                partial: "observ/dataset_run_items/score_close_drawer")
            ]
          end
          format.html do
            if params[:review_mode].present?
              redirect_to review_dataset_run_path(@dataset, @run),
                notice: "Score saved!"
            else
              redirect_to dataset_run_path(@dataset, @run)
            end
          end
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "drawer-content",
              partial: "observ/dataset_run_items/score_drawer",
              locals: { run_item: @run_item, error: score.errors.full_messages.join(", ") }
            )
          end
          format.html do
            if params[:review_mode].present?
              redirect_to review_dataset_run_path(@dataset, @run),
                alert: "Failed to save score: #{score.errors.full_messages.join(', ')}"
            else
              redirect_to dataset_run_path(@dataset, @run), alert: "Failed to save score."
            end
          end
        end
      end
    end

    private

    def set_dataset
      @dataset = Observ::Dataset.find(params[:dataset_id])
    end

    def set_run
      @run = @dataset.runs.find(params[:run_id])
    end

    def set_run_item
      @run_item = @run.run_items.find(params[:id])
    end
  end
end
