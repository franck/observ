module Observ
  class SessionsController < ApplicationController
    def index
      @sessions = Observ::Session.order(start_time: :desc)
      @agent_types = distinct_agent_types
      apply_filters if params[:filter].present?
      @sessions = @sessions.page(params[:page]).per(Observ.config.pagination_per_page)
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

    def distinct_agent_types
      Observ::Session
        .where.not(metadata: nil)
        .pluck(:metadata)
        .filter_map { |m| m&.dig("agent_type") }
        .uniq
        .sort
    end

    def apply_filters
      @sessions = @sessions.where(user_id: params[:filter][:user_id]) if params[:filter][:user_id].present?

      if params[:filter][:start_date].present?
        @sessions = @sessions.where("start_time >= ?", params[:filter][:start_date])
      end

      if params[:filter][:end_date].present?
        @sessions = @sessions.where("start_time <= ?", params[:filter][:end_date])
      end

      if params[:filter][:status].present?
        case params[:filter][:status]
        when "completed"
          @sessions = @sessions.where.not(end_time: nil)
        when "in_progress"
          @sessions = @sessions.where(end_time: nil)
        end
      end

      if params[:filter][:agent_type].present?
        @sessions = @sessions.where_json(:metadata, :agent_type, params[:filter][:agent_type])
      end
    end
  end
end
