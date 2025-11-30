# frozen_string_literal: true

module Observ
  class ScoresController < ApplicationController
    before_action :set_scoreable

    def create
      value = parse_score_value(params[:value], params[:data_type])

      @score = @scoreable.scores.find_or_initialize_by(
        name: params[:name] || "manual",
        source: :manual
      )

      @score.assign_attributes(
        value: value,
        data_type: params[:data_type] || :boolean,
        comment: params[:comment],
        created_by: params[:created_by]
      )

      if @score.save
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_back(fallback_location: root_path, notice: "Score saved.") }
        end
      else
        respond_to do |format|
          format.turbo_stream { render :create_error, status: :unprocessable_content }
          format.html { redirect_back(fallback_location: root_path, alert: "Failed to save score.") }
        end
      end
    end

    def destroy
      @score = @scoreable.scores.find(params[:id])
      @score.destroy

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.remove("score_#{@score.id}") }
        format.html { redirect_back(fallback_location: root_path, notice: "Score deleted.") }
      end
    end

    private

    def set_scoreable
      if params[:session_id]
        @scoreable = Observ::Session.find(params[:session_id])
      elsif params[:trace_id]
        @scoreable = Observ::Trace.find(params[:trace_id])
      end
    end

    def parse_score_value(value, data_type)
      case data_type&.to_sym
      when :boolean
        value.to_i == 1 ? 1.0 : 0.0
      else
        value.to_f
      end
    end
  end
end
