# frozen_string_literal: true

module Observ
  # PromptManager provides a high-level interface for managing prompts
  # with advanced caching, versioning, and comparison capabilities.
  #
  # This service is organized using concerns:
  # - Caching: Cache operations, invalidation, and warming
  # - CacheStatistics: Hit/miss tracking and reporting
  # - VersionManagement: CRUD and state transition operations
  # - Comparison: Version comparison and diffing
  #
  # @example Fetching a prompt with caching
  #   prompt = PromptManager.fetch(name: 'my-prompt', state: :production)
  #
  # @example Creating and promoting a new version
  #   prompt = PromptManager.create(
  #     name: 'my-prompt',
  #     prompt: 'Hello {{name}}',
  #     config: { model: 'gpt-4o' },
  #     promote_to_production: true
  #   )
  #
  # @example Cache management
  #   PromptManager.warm_cache(['prompt1', 'prompt2'])
  #   PromptManager.invalidate_cache(name: 'my-prompt')
  #   stats = PromptManager.cache_stats('my-prompt')
  #
  class PromptManager
    # Extend with concerns for clean separation of responsibilities
    extend Caching
    extend CacheStatistics
    extend VersionManagement
    extend Comparison
  end

  # Custom exceptions
  class StateTransitionError < StandardError; end
  class PromptNotFoundError < StandardError; end
end
