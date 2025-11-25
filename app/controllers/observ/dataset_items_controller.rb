# frozen_string_literal: true

module Observ
  class DatasetItemsController < ApplicationController
    before_action :set_dataset
    before_action :set_item, only: [ :edit, :update, :destroy ]

    def index
      @items = @dataset.items.order(created_at: :desc)

      if params[:status].present?
        @items = @items.where(status: params[:status])
      end

      @items = @items.page(params[:page]).per(Observ.config.pagination_per_page)
    end

    def new
      @item = @dataset.items.build
    end

    def create
      @item = @dataset.items.build(item_params)

      if @item.save
        redirect_to dataset_path(@dataset, tab: "items"),
          notice: "Item added to dataset successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @item.update(item_params)
        redirect_to dataset_path(@dataset, tab: "items"),
          notice: "Item updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @item.destroy
      redirect_to dataset_path(@dataset, tab: "items"),
        notice: "Item removed from dataset."
    end

    private

    def set_dataset
      @dataset = Observ::Dataset.find(params[:dataset_id])
    end

    def set_item
      @item = @dataset.items.find(params[:id])
    end

    def item_params
      permitted = params.require(:observ_dataset_item).permit(:status, :expected_output_text)

      # Handle input as JSON text
      if params[:observ_dataset_item][:input_text].present?
        permitted[:input] = parse_json_field(params[:observ_dataset_item][:input_text])
      end

      # Handle expected_output as JSON text
      if params[:observ_dataset_item][:expected_output_text].present?
        permitted[:expected_output] = parse_json_field(params[:observ_dataset_item][:expected_output_text])
      end

      permitted.except(:expected_output_text)
    end

    def parse_json_field(text)
      return text if text.blank?
      JSON.parse(text)
    rescue JSON::ParserError
      # If it's not valid JSON, treat it as a plain string
      text
    end
  end
end
