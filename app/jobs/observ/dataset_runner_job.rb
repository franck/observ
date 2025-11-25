# frozen_string_literal: true

module Observ
  # Background job for executing dataset evaluations asynchronously
  #
  # This job wraps the DatasetRunnerService to allow dataset runs
  # to be processed in the background via ActiveJob.
  #
  # Usage:
  #   DatasetRunnerJob.perform_later(dataset_run.id)
  #
  # The job will:
  # - Find the dataset run by ID
  # - Skip execution if the run is already completed or running
  # - Execute the DatasetRunnerService
  #
  class DatasetRunnerJob < ApplicationJob
    queue_as :default

    # Retry on transient failures with exponential backoff
    retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
      # Mark the run as failed if all retries exhausted
      dataset_run = Observ::DatasetRun.find_by(id: job.arguments.first)
      if dataset_run
        dataset_run.update!(
          status: :failed,
          metadata: dataset_run.metadata.merge(
            error: error.message,
            error_class: error.class.name,
            failed_at: Time.current.iso8601,
            retries_exhausted: true
          )
        )
      end
    end

    def perform(dataset_run_id)
      dataset_run = Observ::DatasetRun.find(dataset_run_id)

      # Skip if already completed or failed
      return if dataset_run.finished?

      # Skip if already running (avoid duplicate execution)
      return if dataset_run.running?

      DatasetRunnerService.new(dataset_run).call
    end
  end
end
