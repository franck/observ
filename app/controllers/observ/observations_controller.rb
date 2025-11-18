module Observ
  class ObservationsController < ApplicationController
    def index
      @observations = Observ::Observation
        .includes(:trace)
        .order(start_time: :desc)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)

      apply_filters if params[:filter].present?
    end

    def show
      @observation = Observ::Observation.includes(:trace).find(params[:id])

      if @observation.is_a?(Observ::Generation)
        render :show_generation
      else
        render :show_span
      end
    end

    def generations
      @observations = Observ::Generation
        .includes(:trace)
        .order(start_time: :desc)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)

      render :index
    end

    def spans
      @observations = Observ::Span
        .includes(:trace)
        .order(start_time: :desc)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)

      render :index
    end

    private

    def apply_filters
      @observations = @observations.where(type: params[:filter][:type]) if params[:filter][:type].present?
      @observations = @observations.where(name: params[:filter][:name]) if params[:filter][:name].present?
      @observations = @observations.where(model: params[:filter][:model]) if params[:filter][:model].present?

      if params[:filter][:start_date].present?
        @observations = @observations.where("start_time >= ?", params[:filter][:start_date])
      end

      if params[:filter][:end_date].present?
        @observations = @observations.where("start_time <= ?", params[:filter][:end_date])
      end
    end
  end
end
