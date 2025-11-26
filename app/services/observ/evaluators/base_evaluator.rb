# frozen_string_literal: true

module Observ
  module Evaluators
    class BaseEvaluator
      attr_reader :name, :options

      def initialize(name: nil, **options)
        @name = name || default_name
        @options = options
      end

      # Override in subclasses
      def evaluate(run_item)
        raise NotImplementedError, "Subclasses must implement #evaluate"
      end

      # Creates and persists a score for the run item
      def call(run_item)
        return nil unless run_item.trace.present?

        value = evaluate(run_item)
        return nil if value.nil?

        create_or_update_score(run_item, value)
      end

      protected

      def default_name
        self.class.name.demodulize.underscore.sub(/_evaluator$/, "")
      end

      def data_type
        :numeric
      end

      def create_or_update_score(run_item, value)
        score = run_item.scores.find_or_initialize_by(name: name, source: :programmatic)
        score.assign_attributes(
          value: value,
          data_type: data_type,
          comment: options[:comment]
        )
        score.save!
        score
      end
    end
  end
end
