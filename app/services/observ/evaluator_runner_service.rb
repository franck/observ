# frozen_string_literal: true

module Observ
  class EvaluatorRunnerService
    BUILT_IN_EVALUATORS = {
      "exact_match" => Evaluators::ExactMatchEvaluator,
      "contains" => Evaluators::ContainsEvaluator,
      "json_structure" => Evaluators::JsonStructureEvaluator
    }.freeze

    attr_reader :dataset_run, :evaluator_configs

    def initialize(dataset_run, evaluator_configs: nil)
      @dataset_run = dataset_run
      @evaluator_configs = evaluator_configs || default_evaluator_configs
    end

    def call
      return if evaluator_configs.blank?

      dataset_run.run_items.includes(:dataset_item, :trace).find_each do |run_item|
        next unless run_item.succeeded?

        evaluate_item(run_item)
      end

      dataset_run
    end

    def evaluate_item(run_item)
      evaluator_configs.each do |config|
        evaluator = build_evaluator(config)
        next unless evaluator

        evaluator.call(run_item)
      rescue StandardError => e
        Rails.logger.error("Evaluator #{config['type']} failed for run_item #{run_item.id}: #{e.message}")
      end
    end

    private

    def default_evaluator_configs
      # Default to exact_match if no config specified
      [ { "type" => "exact_match" } ]
    end

    def build_evaluator(config)
      type = config["type"]
      evaluator_class = BUILT_IN_EVALUATORS[type]

      return nil unless evaluator_class

      options = config.except("type").symbolize_keys
      evaluator_class.new(**options)
    end
  end
end
