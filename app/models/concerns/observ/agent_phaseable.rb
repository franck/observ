# frozen_string_literal: true

module Observ
  # AgentPhaseable adds phase tracking capabilities to Chat models
  #
  # This concern is optional and should only be included if your agents
  # need to track multi-phase workflows (e.g., scoping -> research -> writing).
  #
  # Prerequisites:
  #   - Chat model must have a `current_phase` string column
  #   - Chat model must include `Observ::ObservabilityInstrumentation`
  #   - Run: rails generate observ:add_phase_tracking
  #
  # Usage:
  #   class Chat < ApplicationRecord
  #     include Observ::ObservabilityInstrumentation
  #     include Observ::AgentPhaseable
  #   end
  #
  # Example:
  #   chat = Chat.create!
  #   chat.transition_to_phase('research')
  #   chat.current_phase # => 'research'
  #
  module AgentPhaseable
    extend ActiveSupport::Concern

    included do
      # Validate that the current_phase column exists
      unless column_names.include?("current_phase")
        raise "AgentPhaseable requires a 'current_phase' column. " \
              "Run: rails generate observ:add_phase_tracking"
      end

      validates :current_phase,
                inclusion: { in: :allowed_phases, allow_nil: true },
                if: -> { respond_to?(:allowed_phases) }
    end

    # Override observability_metadata to include phase information
    def observability_metadata
      metadata = super
      metadata[:agent_phase] = current_phase if current_phase.present?
      metadata
    end

    # Override observability_context to include phase information
    def observability_context
      context = super
      context[:phase] = current_phase if current_phase.present?
      context
    end

    # Transition to a new phase with observability tracking
    #
    # @param new_phase [String, Symbol] The phase to transition to
    # @param metadata [Hash] Optional additional metadata to record with the transition
    # @return [Boolean] true if the transition was successful
    #
    # Example:
    #   chat.transition_to_phase('research', depth: 'deep')
    #
    def transition_to_phase(new_phase, **metadata)
      old_phase = current_phase
      new_phase = new_phase.to_s

      # Validate phase if allowed_phases is defined
      if respond_to?(:allowed_phases) && !allowed_phases.include?(new_phase)
        raise ArgumentError, "Invalid phase: #{new_phase}. Allowed phases: #{allowed_phases.join(', ')}"
      end

      self.current_phase = new_phase
      save!

      # Update observability context if session exists
      if observ_session
        transition_metadata = {
          phase: new_phase,
          phase_transition: "#{old_phase || 'initial'} -> #{new_phase}"
        }.merge(metadata)

        update_observability_context(transition_metadata)
      end

      Rails.logger.info "[AgentPhase] #{self.class.name}##{id} transitioned: #{old_phase || 'initial'} -> #{new_phase}"

      true
    rescue StandardError => e
      Rails.logger.error "[AgentPhase] Failed to transition to #{new_phase}: #{e.message}"
      false
    end

    # Check if currently in a specific phase
    #
    # @param phase [String, Symbol] The phase to check
    # @return [Boolean] true if in the specified phase
    #
    # Example:
    #   chat.in_phase?('research') # => true
    #
    def in_phase?(phase)
      current_phase == phase.to_s
    end

    # Get a list of allowed phases
    # Override this method in your Chat model to define valid phases
    #
    # Example:
    #   class Chat < ApplicationRecord
    #     include Observ::AgentPhaseable
    #
    #     def allowed_phases
    #       %w[scoping research writing review]
    #     end
    #   end
    #
    # @return [Array<String>] List of allowed phase names
    def allowed_phases
      # Default: allow any phase
      # Override in your model to restrict to specific phases
      nil
    end
  end
end
