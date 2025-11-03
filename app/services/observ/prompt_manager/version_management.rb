# frozen_string_literal: true

module Observ
  class PromptManager
    # Concern for prompt version management operations including creation,
    # state transitions (promote, demote, restore), and version queries.
    module VersionManagement
      # ============================================
      # PROMPT CREATION
      # ============================================

      # Create new version of a prompt
      # @param name [String] The prompt name
      # @param prompt [String] The prompt content
      # @param config [Hash] Configuration options (default: {})
      # @param commit_message [String, nil] Optional commit message
      # @param created_by [String, nil] Optional creator identifier
      # @param promote_to_production [Boolean] Whether to promote immediately (default: false)
      # @return [Observ::Prompt] The newly created prompt
      def create(name:, prompt:, config: {}, commit_message: nil, created_by: nil, promote_to_production: false)
        Prompt.create_version(
          name: name,
          prompt: prompt,
          config: config,
          commit_message: commit_message,
          created_by: created_by,
          promote_to_production: promote_to_production
        )
      end

      # ============================================
      # VERSION QUERIES
      # ============================================

      # Get all versions for a prompt
      # @param name [String] The prompt name
      # @return [ActiveRecord::Relation] Versions ordered by version number descending
      def versions(name:)
        Prompt.where(name: name).order(version: :desc)
      end

      # ============================================
      # STATE TRANSITIONS
      # ============================================

      # Rollback to specific version (restore archived to production)
      # @param name [String] The prompt name
      # @param to_version [Integer] The version number to rollback to
      # @return [Observ::Prompt] The rolled back prompt
      # @raise [StateTransitionError] If trying to rollback to a draft version
      def rollback(name:, to_version:)
        prompt = Prompt.find_by!(name: name, version: to_version)

        if prompt.archived?
          prompt.restore!
          prompt
        elsif prompt.production?
          # Already production, nothing to do
          prompt
        else
          raise StateTransitionError, "Cannot rollback to draft version"
        end
      end

      # Promote specific version to production
      # @param name [String] The prompt name
      # @param version [Integer] The version number to promote
      # @return [Observ::Prompt] The promoted prompt
      def promote(name:, version:)
        prompt = Prompt.find_by!(name: name, version: version)
        prompt.promote! if prompt.draft?
        prompt
      end

      # Demote production to archived
      # @param name [String] The prompt name
      # @param version [Integer] The version number to demote
      # @return [Observ::Prompt] The demoted prompt
      def demote(name:, version:)
        prompt = Prompt.find_by!(name: name, version: version)
        prompt.demote! if prompt.production?
        prompt
      end

      # Restore archived to production
      # @param name [String] The prompt name
      # @param version [Integer] The version number to restore
      # @return [Observ::Prompt] The restored prompt
      def restore(name:, version:)
        prompt = Prompt.find_by!(name: name, version: version)
        prompt.restore! if prompt.archived?
        prompt
      end
    end
  end
end
