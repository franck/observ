# frozen_string_literal: true

module Observ
  class DatasetsController < ApplicationController
    before_action :set_dataset, only: [ :show, :edit, :update, :destroy ]

    def index
      @datasets = Observ::Dataset.order(updated_at: :desc)

      if params[:search].present?
        @datasets = @datasets.where("name LIKE ?", "%#{params[:search]}%")
      end

      @datasets = @datasets.page(params[:page]).per(Observ.config.pagination_per_page)
    end

    def show
      @items = @dataset.items.order(created_at: :desc).page(params[:items_page]).per(10)
      @runs = @dataset.runs.order(created_at: :desc).page(params[:runs_page]).per(10)
      @active_tab = params[:tab] || "items"
    end

    def new
      @dataset = Observ::Dataset.new
      @agents = available_agents
    end

    def create
      @dataset = Observ::Dataset.new(dataset_params)

      if @dataset.save
        redirect_to dataset_path(@dataset), notice: "Dataset '#{@dataset.name}' created successfully."
      else
        @agents = available_agents
        render :new, status: :unprocessable_content
      end
    end

    def edit
      @agents = available_agents
    end

    def update
      if @dataset.update(dataset_params)
        redirect_to dataset_path(@dataset), notice: "Dataset '#{@dataset.name}' updated successfully."
      else
        @agents = available_agents
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      name = @dataset.name
      @dataset.destroy
      redirect_to datasets_path, notice: "Dataset '#{name}' deleted successfully."
    end

    private

    def set_dataset
      @dataset = Observ::Dataset.find(params[:id])
    end

    def dataset_params
      params.require(:observ_dataset).permit(:name, :description, :agent_class)
    end

    def available_agents
      Observ::AgentProvider.all_agents.map do |agent|
        [ agent.display_name, agent.name ]
      end
    end
  end
end
