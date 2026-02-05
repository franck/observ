# frozen_string_literal: true

module Observ
  # Service responsible for executing dataset evaluations
  #
  # This service runs an agent against all items in a dataset run,
  # creating traces for each execution and tracking results.
  #
  # Usage:
  #   run = DatasetRun.find(1)
  #   DatasetRunnerService.new(run).call
  #
  # The service:
  # - Updates run status to :running at start
  # - Processes each dataset item through the AgentExecutorService
  # - Creates a session and trace for each item execution
  # - Records errors for failed items
  # - Updates metrics after completion
  # - Sets final status to :completed or :failed
  #
  class DatasetRunnerService
    attr_reader :dataset_run, :dataset

    def initialize(dataset_run)
      @dataset_run = dataset_run
      @dataset = dataset_run.dataset
    end

    def call
      dataset_run.update!(status: :running)

      process_all_items

      dataset_run.update_metrics!
      determine_final_status
    rescue StandardError => e
      handle_run_failure(e)
      raise
    end

    private

    def process_all_items
      dataset_run.run_items.includes(:dataset_item).find_each do |run_item|
        process_item(run_item)
      end
    end

    def process_item(run_item)
      session = create_session_for_item(run_item)
      trace = create_trace_for_item(session, run_item)

      begin
        result = execute_agent(run_item.dataset_item.input, session)
        finalize_successful_item(run_item, trace, result)
      rescue StandardError => e
        finalize_failed_item(run_item, trace, e)
      end
    end

    def create_session_for_item(run_item)
      Observ::Session.create!(
        user_id: "dataset_run_#{dataset_run.id}",
        metadata: {
          dataset_id: dataset.id,
          dataset_run_id: dataset_run.id,
          dataset_item_id: run_item.dataset_item_id,
          source: "dataset_evaluation"
        }
      )
    end

    def create_trace_for_item(session, run_item)
      session.create_trace(
        name: "dataset_evaluation",
        input: run_item.dataset_item.input,
        metadata: {
          dataset_id: dataset.id,
          dataset_name: dataset.name,
          dataset_run_id: dataset_run.id,
          dataset_run_name: dataset_run.name,
          dataset_item_id: run_item.dataset_item_id,
          agent_class: dataset.agent_class
        },
        tags: ["dataset_evaluation", dataset.name, dataset_run.name]
      )
    end

    def execute_agent(input, session)
      executor = AgentExecutorService.new(
        dataset.agent,
        observability_session: session,
        context: {
          dataset_id: dataset.id,
          dataset_run_id: dataset_run.id
        }
      )
      executor.call(input)
    end

    def finalize_successful_item(run_item, trace, result)
      output = extract_output(result)
      trace.finalize(output: output)

      run_item.update!(
        trace: trace,
        error: nil
      )
    end

    def finalize_failed_item(run_item, trace, error)
      trace.finalize(
        output: nil,
        metadata: { error: error.message, error_class: error.class.name }
      )

      run_item.update!(
        trace: trace,
        error: "#{error.class.name}: #{error.message}"
      )
    end

    def extract_output(result)
      case result
      when String
        result
      when Hash
        result
      else
        result.respond_to?(:to_h) ? result.to_h : result.to_s
      end
    end

    def determine_final_status
      if dataset_run.failed_items == dataset_run.total_items
        dataset_run.update!(status: :failed)
      else
        dataset_run.update!(status: :completed)
      end
    end

    def handle_run_failure(error)
      dataset_run.update!(
        status: :failed,
        metadata: dataset_run.metadata.merge(
          error: error.message,
          error_class: error.class.name,
          failed_at: Time.current.iso8601
        )
      )
    end
  end
end
