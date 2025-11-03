# frozen_string_literal: true

module Observ
  class PromptForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :prompt, :string
    attribute :config, :string  # JSON string from form
    attribute :commit_message, :string
    attribute :promote_to_production, :boolean, default: false
    attribute :from_version, :integer

    # For dependency injection
    attr_accessor :created_by
    attr_reader :persisted_prompt

    validates :name, presence: true
    validates :prompt, presence: true
    validate :config_must_be_valid_json

    def initialize(attributes = {})
      super
      load_from_version if from_version.present? && name.present?
    end

    def save
      return false unless valid?

      @persisted_prompt = PromptManager.create(
        name: name,
        prompt: prompt,
        config: parsed_config,
        commit_message: commit_message,
        created_by: created_by,
        promote_to_production: promote_to_production
      )

      true
    rescue ActiveRecord::RecordInvalid => e
      # Copy model errors to form
      e.record.errors.each do |error|
        errors.add(error.attribute, error.message)
      end
      false
    end

    def parsed_config
      return {} if config.blank?
      JSON.parse(config)
    rescue JSON::ParserError
      {}
    end

    # For form display - returns formatted JSON string
    def config_json
      return "" if config.blank?
      config.is_a?(String) ? config : JSON.pretty_generate(config)
    end

    # ActiveModel compatibility for form_with
    def model_name
      ActiveModel::Name.new(self.class, nil, "observ_prompt_form")
    end

    def persisted?
      false
    end

    def to_key
      nil
    end

    def to_model
      self
    end

    private

    def config_must_be_valid_json
      return if config.blank?
      JSON.parse(config)
    rescue JSON::ParserError => e
      errors.add(:config, "must be valid JSON: #{e.message}")
    end

    def load_from_version
      source = Prompt.find_by(name: name, version: from_version)
      return unless source

      self.prompt = source.prompt
      self.config = source.config.present? ? JSON.pretty_generate(source.config) : ""
    end
  end
end
