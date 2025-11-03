module Observ
  class SessionsController < ApplicationController
    def index
      @sessions = Observ::Session.order(start_time: :desc)
      apply_filters if params[:filter].present?
      @sessions = @sessions.page(params[:page]).per(25)
    end

    def show
      @session = Observ::Session.find(params[:id])
      @traces = @session.traces.order(start_time: :asc)
      @session_metrics = @session.session_metrics
      @chat = @session.chat
    end

    def metrics
      @session = Observ::Session.find(params[:id])
      render json: @session.session_metrics
    end

    def drawer_test
      @session = Observ::Session.find(params[:id])
    end

    def annotations_drawer
      @session = Observ::Session.find(params[:id])
      @annotations = @session.annotations.recent
      @annotation = @session.annotations.build
    end

    private

    def apply_filters
      @sessions = @sessions.where(user_id: params[:filter][:user_id]) if params[:filter][:user_id].present?

      if params[:filter][:start_date].present?
        @sessions = @sessions.where("start_time >= ?", params[:filter][:start_date])
      end

      if params[:filter][:end_date].present?
        @sessions = @sessions.where("start_time <= ?", params[:filter][:end_date])
      end
    end
  end
end
