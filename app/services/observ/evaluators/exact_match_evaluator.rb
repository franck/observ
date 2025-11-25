# frozen_string_literal: true

module Observ
  module Evaluators
    class ExactMatchEvaluator < BaseEvaluator
      def evaluate(run_item)
        return nil if run_item.expected_output.blank?

        run_item.output_matches? ? 1.0 : 0.0
      end

      protected

      def data_type
        :boolean
      end

      def default_name
        "exact_match"
      end
    end
  end
end
