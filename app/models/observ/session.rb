# frozen_string_literal: true

module Observ
  class Session < ApplicationRecord
    self.table_name = "observ_sessions"

  has_many :traces, class_name: "Observ::Trace",
           foreign_key: :observ_session_id, dependent: :destroy, inverse_of: :observ_session
  has_many :annotations, as: :annotatable, dependent: :destroy

    validates :session_id, presence: true, uniqueness: true
    validates :start_time, presence: true

    before_validation :set_session_id, on: :create
    before_validation :set_start_time, on: :create

    def create_trace(name: nil, input: nil, metadata: {}, tags: [])
      traces.create!(
        trace_id: SecureRandom.uuid,
        name: name || "chat_exchange",
        input: input.is_a?(String) ? input : input.to_json,
        metadata: metadata,
        tags: tags,
        user_id: user_id,
        start_time: Time.current
      )
    end

    def finalize
      update!(end_time: Time.current)
      update_aggregated_metrics
    end

    def duration_s
      return nil unless end_time
      (end_time - start_time).round(1)
    end

    def average_llm_latency_ms
      generations = Observ::Generation.joins(trace: :observ_session)
                                      .where(observ_sessions: { id: id })
                                      .where.not(end_time: nil)
      return 0 if generations.empty?

      total_duration = generations.sum do |g|
        ((g.end_time - g.start_time) * 1000).round(2)
      end
      (total_duration / generations.count).round(0)
    end

    def session_metrics
      if end_time.nil?
        {
          session_id: session_id,
          total_traces: traces.count,
          total_llm_calls: generation_count,
          total_tokens: traces.sum(:total_tokens),
          total_cost: traces.sum(:total_cost).to_f,
          total_llm_duration_ms: calculate_total_llm_duration,
          average_llm_latency_ms: average_llm_latency_ms,
          duration_s: duration_s
        }
      else
        {
          session_id: session_id,
          total_traces: total_traces_count,
          total_llm_calls: total_llm_calls_count,
          total_tokens: total_tokens,
          total_cost: total_cost.to_f,
          total_llm_duration_ms: total_llm_duration_ms,
          average_llm_latency_ms: average_llm_latency_ms,
          duration_s: duration_s
        }
      end
    end

    def update_aggregated_metrics
      update_columns(
        total_traces_count: traces.count,
        total_llm_calls_count: generation_count,
        total_tokens: traces.sum(:total_tokens),
        total_cost: traces.sum(:total_cost),
        total_llm_duration_ms: calculate_total_llm_duration
      )
    end

    def update_metadata(new_metadata)
      self.metadata = (self.metadata || {}).merge(new_metadata)
      save
    end

    def instrument_chat(chat_instance, context: {})
      instrumenter = Observ::ChatInstrumenter.new(
        self,
        chat_instance,
        context: context
      )
      instrumenter.instrument!
      instrumenter
    end

    def chat
      @chat ||= Chat.find_by(observability_session_id: session_id)
    end

    private

    def set_session_id
      self.session_id ||= SecureRandom.uuid
    end

    def set_start_time
      self.start_time ||= Time.current
    end

    def generation_count
      Observ::Generation.joins(:trace)
                        .where(observ_traces: { observ_session_id: id })
                        .count
    end

    def calculate_total_llm_duration
      Observ::Generation.joins(:trace)
                        .where(observ_traces: { observ_session_id: id })
                        .where.not(end_time: nil)
                        .sum do |g|
        ((g.end_time - g.start_time) * 1000).round(2)
      end || 0
    end
  end
end
