# frozen_string_literal: true

module Observ
  class GuardrailService
    class << self
      def evaluate_trace(trace)
        return if trace.in_review_queue?

        trace_rules.each do |rule|
          next unless rule[:condition].call(trace)

          trace.enqueue_for_review!(
            reason: rule[:name].to_s,
            priority: rule[:priority],
            details: rule[:details]&.call(trace) || {}
          )
          return # One reason is enough
        end
      end

      def evaluate_session(session)
        return if session.in_review_queue?

        session_rules.each do |rule|
          next unless rule[:condition].call(session)

          session.enqueue_for_review!(
            reason: rule[:name].to_s,
            priority: rule[:priority],
            details: rule[:details]&.call(session) || {}
          )
          return
        end
      end

      def evaluate_all_recent(since: 1.hour.ago)
        Observ::Trace.where(created_at: since..).find_each do |trace|
          evaluate_trace(trace)
        end

        Observ::Session.where(created_at: since..).find_each do |session|
          evaluate_session(session)
        end
      end

      def random_sample(scope:, percentage: 5)
        items = scope.where(created_at: 1.day.ago..)
                     .left_joins(:review_item)
                     .where(observ_review_items: { id: nil })

        sample_size = [ (items.count * percentage / 100.0).ceil, 1 ].max

        items.order("RANDOM()").limit(sample_size).find_each do |item|
          item.enqueue_for_review!(reason: "random_sample", priority: :normal)
        end
      end

      private

      def trace_rules
        [
          {
            name: :error_detected,
            priority: :critical,
            condition: ->(t) { t.metadata&.dig("error").present? },
            details: ->(t) { { error: t.metadata["error"] } }
          },
          {
            name: :high_cost,
            priority: :high,
            condition: ->(t) { t.total_cost.present? && t.total_cost > thresholds[:trace_cost] },
            details: ->(t) { { cost: t.total_cost.to_f, threshold: thresholds[:trace_cost] } }
          },
          {
            name: :high_latency,
            priority: :normal,
            condition: ->(t) { t.duration_ms.present? && t.duration_ms > thresholds[:latency_ms] },
            details: ->(t) { { latency_ms: t.duration_ms, threshold: thresholds[:latency_ms] } }
          },
          {
            name: :no_output,
            priority: :high,
            condition: ->(t) { t.output.blank? && t.end_time.present? }
          },
          {
            name: :high_token_count,
            priority: :normal,
            condition: ->(t) { t.total_tokens.present? && t.total_tokens > thresholds[:tokens] },
            details: ->(t) { { tokens: t.total_tokens, threshold: thresholds[:tokens] } }
          }
        ]
      end

      def session_rules
        [
          {
            name: :high_cost,
            priority: :high,
            condition: ->(s) { s.total_cost.present? && s.total_cost > thresholds[:session_cost] },
            details: ->(s) { { cost: s.total_cost.to_f, threshold: thresholds[:session_cost] } }
          },
          {
            name: :short_session,
            priority: :normal,
            condition: ->(s) { s.total_traces_count == 1 && s.end_time.present? },
            details: ->(s) { { trace_count: s.total_traces_count } }
          },
          {
            name: :many_traces,
            priority: :normal,
            condition: ->(s) { s.total_traces_count.present? && s.total_traces_count > thresholds[:max_traces] },
            details: ->(s) { { trace_count: s.total_traces_count, threshold: thresholds[:max_traces] } }
          }
        ]
      end

      def thresholds
        @thresholds ||= {
          trace_cost: 0.10,
          session_cost: 0.50,
          latency_ms: 30_000,
          tokens: 10_000,
          max_traces: 20
        }
      end
    end
  end
end
