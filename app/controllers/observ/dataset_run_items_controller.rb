# frozen_string_literal: true

module Observ
  class DatasetRunItemsController < ApplicationController
    before_action :set_dataset
    before_action :set_run
    before_action :set_run_item

    def details_drawer
      # The drawer template will use @run_item
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
