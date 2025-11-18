module Observ
  class TracesController < ApplicationController
    def index
      @traces = Observ::Trace
        .includes(:observ_session)
        .order(start_time: :desc)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)

      apply_filters if params[:filter].present?
    end

    def show
      @trace = Observ::Trace.includes(:observations).find(params[:id])
      @observations = @trace.observations.order(start_time: :asc)
      @generations = @trace.generations
      @spans = @trace.spans
    end

    def search
      @traces = Observ::Trace
        .includes(:observ_session)
        .where("trace_id LIKE ? OR name LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
        .order(start_time: :desc)
        .limit(50)

      render :index
    end

    def annotations_drawer
      @trace = Observ::Trace.find(params[:id])
      @annotations = @trace.annotations.recent
      @annotation = @trace.annotations.build
    end

    def text_output_drawer
      @trace = Observ::Trace.includes(:observations, :annotations, observ_session: :annotations).find(params[:id])
      @formatted_text = Observ::TraceTextFormatter.new(@trace).format
    end

    private

    def apply_filters
      if params[:filter][:session_id].present?
        session = Observ::Session.find_by(session_id: params[:filter][:session_id])
        @traces = @traces.where(observ_session_id: session&.id) if session
      end

      @traces = @traces.where(name: params[:filter][:name]) if params[:filter][:name].present?

      if params[:filter][:start_date].present?
        @traces = @traces.where("start_time >= ?", params[:filter][:start_date])
      end

      if params[:filter][:end_date].present?
        @traces = @traces.where("start_time <= ?", params[:filter][:end_date])
      end
    end
  end
end
