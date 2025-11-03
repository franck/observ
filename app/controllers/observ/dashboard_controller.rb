module Observ
  class DashboardController < ApplicationController
    def index
      @time_period = params[:period] || "24h"
      @metrics = calculate_dashboard_metrics
      @recent_sessions = Observ::Session.order(start_time: :desc).limit(10)
      @cost_by_model = calculate_cost_by_model
      @token_usage_over_time = calculate_token_usage_over_time
      @metrics_by_agent = calculate_metrics_by_agent
    end

    def metrics
      render json: calculate_dashboard_metrics
    end

    def cost_analysis
      render json: {
        by_model: calculate_cost_by_model,
        over_time: calculate_cost_over_time
      }
    end

    private

    def calculate_dashboard_metrics
      time_range = time_range_from_period(@time_period)
      sessions = Observ::Session.where("start_time >= ?", time_range)

      period_duration = Time.current - time_range
      previous_time_range = time_range - period_duration
      previous_sessions = Observ::Session.where("start_time >= ? AND start_time < ?", previous_time_range, time_range)

      current_metrics = {
        total_sessions: sessions.count,
        total_traces: Observ::Trace.joins(:observ_session).where("observ_sessions.start_time >= ?", time_range).count,
        total_llm_calls: Observ::Generation.joins(trace: :observ_session).where("observ_sessions.start_time >= ?", time_range).count,
        total_tokens: Observ::Trace.joins(:observ_session).where("observ_sessions.start_time >= ?", time_range).sum(:total_tokens),
        total_cost: Observ::Trace.joins(:observ_session).where("observ_sessions.start_time >= ?", time_range).sum(:total_cost).to_f,
        avg_latency_ms: calculate_average_llm_latency(time_range),
        success_rate: calculate_success_rate(time_range),
        avg_cost_per_call: calculate_avg_cost_per_call(sessions)
      }

      previous_metrics = {
        total_sessions: previous_sessions.count,
        total_tokens: Observ::Trace.joins(:observ_session).where("observ_sessions.start_time >= ? AND observ_sessions.start_time < ?", previous_time_range, time_range).sum(:total_tokens),
        total_cost: Observ::Trace.joins(:observ_session).where("observ_sessions.start_time >= ? AND observ_sessions.start_time < ?", previous_time_range, time_range).sum(:total_cost).to_f
      }

      current_metrics.merge(
        trends: calculate_trends(current_metrics, previous_metrics)
      )
    end

    def calculate_cost_by_model
      Observ::Generation
        .where("created_at >= ?", time_range_from_period(@time_period))
        .group(:model)
        .sum(:cost_usd)
        .transform_values(&:to_f)
    end

    def calculate_token_usage_over_time
      Observ::Session
        .where("start_time >= ?", time_range_from_period(@time_period))
        .group("DATE(start_time)")
        .sum(:total_tokens)
    end

    def calculate_cost_over_time
      Observ::Session
        .where("start_time >= ?", time_range_from_period(@time_period))
        .group("DATE(start_time)")
        .sum(:total_cost)
        .transform_values(&:to_f)
    end

    def calculate_average_llm_latency(time_range)
      generations = Observ::Generation
        .joins(trace: :observ_session)
        .where("observ_sessions.start_time >= ?", time_range)
        .where.not(end_time: nil)

      return 0 if generations.empty?

      total_duration = generations.sum { |g| ((g.end_time - g.start_time) * 1000).round(2) }
      (total_duration / generations.count).round(0)
    end

    def calculate_success_rate(time_range)
      total = Observ::Generation
        .joins(trace: :observ_session)
        .where("observ_sessions.start_time >= ?", time_range)
        .count

      return 100.0 if total.zero?

      failed = Observ::Generation
        .joins(trace: :observ_session)
        .where("observ_sessions.start_time >= ?", time_range)
        .where.not(status_message: nil)
        .count

      (((total - failed).to_f / total) * 100).round(1)
    end

    def calculate_avg_cost_per_call(sessions)
      time_range = time_range_from_period(@time_period)
      total_cost = Observ::Trace.joins(:observ_session).where("observ_sessions.start_time >= ?", time_range).sum(:total_cost).to_f
      total_calls = Observ::Generation.joins(trace: :observ_session).where("observ_sessions.start_time >= ?", time_range).count

      return 0.0 if total_calls.zero?

      (total_cost / total_calls).round(6)
    end

    def calculate_trends(current, previous)
      {
        sessions: calculate_percentage_change(current[:total_sessions], previous[:total_sessions]),
        tokens: calculate_percentage_change(current[:total_tokens], previous[:total_tokens]),
        cost: calculate_percentage_change(current[:total_cost], previous[:total_cost])
      }
    end

    def calculate_percentage_change(current, previous)
      return 0 if previous.zero?
      (((current - previous).to_f / previous) * 100).round(1)
    end

    def calculate_metrics_by_agent
      time_range = time_range_from_period(@time_period)
      sessions = Observ::Session.where("start_time >= ?", time_range)

      sessions.group_by { |s| s.metadata&.dig("agent_type") || "Unknown" }.map do |agent_type, agent_sessions|
        session_ids = agent_sessions.map(&:id)
        traces = Observ::Trace.where(observ_session_id: session_ids)
        generations = Observ::Generation.joins(:trace).where(observ_traces: { observ_session_id: session_ids })

        {
          agent_type: agent_type,
          sessions: agent_sessions.count,
          traces: traces.count,
          llm_calls: generations.count,
          tokens: traces.sum(:total_tokens),
          cost: traces.sum(:total_cost).to_f
        }
      end.sort_by { |m| -m[:cost] }
    end

    def time_range_from_period(period)
      case period
      when "24h" then 24.hours.ago
      when "7d" then 7.days.ago
      when "30d" then 30.days.ago
      else 100.years.ago
      end
    end
  end
end
