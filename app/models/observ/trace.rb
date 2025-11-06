# frozen_string_literal: true

module Observ
  class Trace < ApplicationRecord
    self.table_name = "observ_traces"

    belongs_to :observ_session, class_name: "Observ::Session", inverse_of: :traces
    has_many :observations, class_name: "Observ::Observation",
      foreign_key: :observ_trace_id, dependent: :destroy, inverse_of: :trace
    belongs_to :message, optional: true
    has_many :annotations, as: :annotatable, dependent: :destroy

    validates :trace_id, presence: true, uniqueness: true
    validates :start_time, presence: true

    after_save :update_session_metrics, if: :saved_change_to_total_cost_or_total_tokens?

    def create_generation(name: "llm_generation", model: nil, metadata: {}, **options)
      observations.create!(
        observation_id: SecureRandom.uuid,
        type: "Observ::Generation",
        name: name,
        model: model,
        metadata: metadata,
        start_time: Time.current,
        **options.slice(:model_parameters, :prompt_name, :prompt_version, :parent_observation_id)
      )
    end

    def create_span(name:, input: nil, metadata: {}, parent_observation_id: nil)
      observations.create!(
        observation_id: SecureRandom.uuid,
        type: "Observ::Span",
        name: name,
        input: input.is_a?(String) ? input : input.to_json,
        metadata: metadata,
        parent_observation_id: parent_observation_id,
        start_time: Time.current
      )
    end

    def finalize(output: nil, metadata: {})
      merged_metadata = (self.metadata || {}).merge(metadata)
      update!(
        output: output.is_a?(String) ? output : output.to_json,
        metadata: merged_metadata,
        end_time: Time.current
      )
      update_aggregated_metrics
    end

    def finalize_with_response(response)
      if response.is_a?(String)
        finalize(output: response)
        return response
      end

      response_metadata = extract_response_metadata(response)

      finalize(
        output: response.respond_to?(:content) ? response.content : response.to_s,
        metadata: response_metadata
      )

      response.respond_to?(:content) ? response.content : response.to_s
    end

    def duration_ms
      return nil unless end_time
      ((end_time - start_time) * 1000).round(2)
    end

    def update_aggregated_metrics
      new_total_cost = generations.sum(:cost_usd) || 0.0

      # Database-agnostic token calculation
      new_total_tokens = generations.sum do |gen|
        gen.usage&.dig("total_tokens") || 0
      end

      update_columns(
        total_cost: new_total_cost,
        total_tokens: new_total_tokens
      )
    end

    def generations
      observations.where(type: "Observ::Generation")
    end

    def spans
      observations.where(type: "Observ::Span")
    end

    def models_used
      generations.where.not(model: nil).distinct.pluck(:model)
    end

    private

    def extract_response_metadata(response)
      metadata = {}

      metadata[:model_id] = response.model_id if response.respond_to?(:model_id)
      metadata[:input_tokens] = response.input_tokens if response.respond_to?(:input_tokens)

      if response.respond_to?(:output_tokens)
        metadata[:output_tokens] = response.output_tokens
        metadata[:total_tokens] = (response.input_tokens || 0) + response.output_tokens
      end

      metadata[:role] = response.role if response.respond_to?(:role)

      if response.respond_to?(:tool_calls) && response.tool_calls&.any?
        metadata[:tool_calls_count] = response.tool_calls.count
        metadata[:tool_calls] = response.tool_calls.map do |tc|
          {
            name: tc.respond_to?(:name) ? tc.name : nil,
            arguments: tc.respond_to?(:arguments) ? tc.arguments : nil
          }.compact
        end
      end

      metadata
    end

    def saved_change_to_total_cost_or_total_tokens?
      saved_change_to_total_cost? || saved_change_to_total_tokens?
    end

    def update_session_metrics
      observ_session&.update_aggregated_metrics
    end
  end
end
