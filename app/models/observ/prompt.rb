# frozen_string_literal: true

module Observ
  class Prompt < ApplicationRecord
    include AASM

    self.table_name = "observ_prompts"

    # ============================================
    # VALIDATIONS
    # ============================================
    validates :name, presence: true
    validates :prompt, presence: true
    validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :state, presence: true, inclusion: { in: %w[draft production archived] }

    # Only ONE production version per prompt name
    validate :only_one_production_per_name, if: :production?

    # Prevent editing immutable prompts
    before_update :ensure_editable!, if: :content_changed?

    # Ensure config is always a Hash, not a String
    before_save :normalize_config

    # ============================================
    # SCOPES
    # ============================================
    scope :by_name, ->(name) { where(name: name) }
    scope :latest_version, -> { order(version: :desc).limit(1) }

    # ============================================
    # AASM STATE MACHINE
    # ============================================
    aasm column: :state, after_commit: true do
      state :draft, initial: true
      state :production
      state :archived

      event :promote do
        transitions from: :draft, to: :production, after: :demote_other_production_versions
      end

      event :demote do
        transitions from: :production, to: :archived
      end

      event :restore do
        transitions from: :archived, to: :production, after: :demote_other_production_versions
      end

      # Invalidate cache after any state transition
      after_all_transitions :invalidate_cache_after_transition
    end

    # ============================================
    # CALLBACKS
    # ============================================

    # Invalidate cache after updates or deletion
    after_save :invalidate_cache_if_changed
    after_destroy :invalidate_cache_on_destroy

    # ============================================
    # CLASS METHODS
    # ============================================

    # Fetch prompt by name, state, or version
    def self.fetch(name:, version: nil, state: :production, fallback: nil)
      state ||= Observ.config.prompt_default_state
      cache_key = cache_key_for(name: name, version: version, state: state)
      cache_ttl = Observ.config.prompt_cache_ttl

      Rails.cache.fetch(cache_key, expires_in: cache_ttl) do
        fetch_from_database(name: name, version: version, state: state, fallback: fallback)
      end
    end

    def self.fetch_from_database(name:, version:, state:, fallback:)
      query = where(name: name)

      prompt = if version.present?
        query.find_by(version: version)
      else
        query.public_send(state).first
      end

      return prompt if prompt
      return fallback if fallback
      raise PromptNotFoundError, "Prompt '#{name}' not found"
    end

    def self.cache_key_for(name:, version:, state:)
      "observ:prompt:#{name}:#{version || state}"
    end

    def self.clear_cache(name:)
      # Clear all cache keys for this prompt
      [ :draft, :production, :archived ].each do |state|
        Rails.cache.delete(cache_key_for(name: name, version: nil, state: state))
      end
    end

    # Create new version (auto-increment)
    def self.create_version(name:, prompt:, config: {}, commit_message: nil, created_by: nil, promote_to_production: false)
      latest_version = where(name: name).maximum(:version) || 0
      new_version = latest_version + 1

      new_prompt = create!(
        name: name,
        prompt: prompt,
        version: new_version,
        config: config,
        commit_message: commit_message,
        created_by: created_by,
        state: :draft
      )

      new_prompt.promote! if promote_to_production
      new_prompt
    end

    # ============================================
    # INSTANCE METHODS
    # ============================================

    # Compile prompt with variable substitution
    def compile(variables = {})
      compiled = prompt.dup

      variables.each do |key, value|
        compiled.gsub!("{{#{key}}}", value.to_s)
      end

      compiled
    end

    # Compile with validation (raises if missing variables)
    def compile_with_validation(variables = {})
      compiled = compile(variables)

      # Check for remaining unsubstituted variables
      remaining_vars = compiled.scan(/\{\{(\w+)\}\}/).flatten
      if remaining_vars.any?
        raise VariableSubstitutionError, "Missing variables: #{remaining_vars.join(', ')}"
      end

      compiled
    end

    # Immutability checks
    def editable?
      draft?
    end

    def immutable?
      production? || archived?
    end

    def can_delete?
      draft? || archived?
    end

    # Clone to new draft version
    def clone_to_draft
      self.class.create_version(
        name: name,
        prompt: prompt,
        config: config,
        commit_message: "Cloned from v#{version} (#{state})",
        created_by: nil
      )
    end

    # Version navigation
    def previous_version
      self.class.where(name: name).where("version < ?", version).order(version: :desc).first
    end

    def next_version
      self.class.where(name: name).where("version > ?", version).order(version: :asc).first
    end

    def latest_version
      self.class.where(name: name).order(version: :desc).first
    end

    # Export
    def to_json_export
      as_json(except: [ :id, :created_at, :updated_at ])
    end

    def to_yaml_export
      to_json_export.to_yaml
    end

    private

    # ============================================
    # VALIDATIONS
    # ============================================

    def only_one_production_per_name
      existing_production = self.class.where(name: name, state: :production).where.not(id: id).exists?
      if existing_production
        errors.add(:state, "Only one production version allowed per prompt name")
      end
    end

    def ensure_editable!
      if immutable?
        errors.add(:base, "Cannot edit #{state} prompt. Clone to draft first.")
        raise ActiveRecord::RecordInvalid, self
      end
    end

    def content_changed?
      prompt_changed? || config_changed?
    end

    # ============================================
    # CALLBACKS
    # ============================================

    def demote_other_production_versions
      self.class.where(name: name, state: :production).where.not(id: id).update_all(state: :archived)
    end

    def invalidate_cache_after_transition
      Observ::PromptManager.invalidate_cache(name: name)
      Rails.logger.info("Cache invalidated after state transition for #{name} v#{version}")
    end

    def invalidate_cache_if_changed
      return unless saved_change_to_prompt? || saved_change_to_config? || saved_change_to_state?

      Observ::PromptManager.invalidate_cache(name: name)
    end

    def invalidate_cache_on_destroy
      Observ::PromptManager.invalidate_cache(name: name)
    end

    def clear_prompt_cache
      self.class.clear_cache(name: name)
    end

    def normalize_config
      return if config.nil?

      # If config is a String, parse it to a Hash
      if config.is_a?(String)
        self.config = begin
          JSON.parse(config)
        rescue JSON::ParserError
          {} # Default to empty hash if parsing fails
        end
      end

      # Ensure it's a Hash (could be other types in edge cases)
      self.config = {} unless config.is_a?(Hash)
    end
  end

  # Custom exceptions
  class PromptNotFoundError < StandardError; end
  class VariableSubstitutionError < StandardError; end
end
