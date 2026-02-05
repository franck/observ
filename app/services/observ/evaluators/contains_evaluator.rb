# frozen_string_literal: true

module Observ
  module Evaluators
    class ContainsEvaluator < BaseEvaluator
      def evaluate(run_item)
        keywords = options[:keywords] || extract_keywords_from_expected(run_item)
        return nil if keywords.blank?

        output = normalize_output(run_item.actual_output)
        return 0.0 if output.blank?

        matched = keywords.count { |kw| output.downcase.include?(kw.downcase) }
        matched.to_f / keywords.size
      end

      protected

      def default_name
        "contains"
      end

      private

      def extract_keywords_from_expected(run_item)
        expected = run_item.expected_output
        return [] if expected.blank?

        case expected
        when Hash
          expected["keywords"] || expected[:keywords] || []
        when Array
          expected
        when String
          [expected]
        else
          []
        end
      end

      def normalize_output(output)
        case output
        when Hash
          output.to_json
        when String
          output
        else
          output.to_s
        end
      end
    end
  end
end
