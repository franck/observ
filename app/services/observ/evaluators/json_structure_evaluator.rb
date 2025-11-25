# frozen_string_literal: true

module Observ
  module Evaluators
    class JsonStructureEvaluator < BaseEvaluator
      def evaluate(run_item)
        required_keys = options[:required_keys] || extract_keys_from_expected(run_item)
        return nil if required_keys.blank?

        output = parse_output(run_item.actual_output)
        return 0.0 if output.nil?

        present_keys = required_keys.count { |key| output.key?(key.to_s) || output.key?(key.to_sym) }
        present_keys.to_f / required_keys.size
      end

      protected

      def default_name
        "json_structure"
      end

      private

      def extract_keys_from_expected(run_item)
        expected = run_item.expected_output
        return [] unless expected.is_a?(Hash)

        expected.keys.map(&:to_s)
      end

      def parse_output(output)
        case output
        when Hash
          output
        when String
          JSON.parse(output) rescue nil
        else
          nil
        end
      end
    end
  end
end
