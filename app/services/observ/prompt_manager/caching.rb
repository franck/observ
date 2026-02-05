# frozen_string_literal: true

module Observ
  class PromptManager
    # Concern for prompt caching operations including cache key generation,
    # fetching with cache, invalidation, and cache warming.
    module Caching
      # ============================================
      # CACHE KEY MANAGEMENT
      # ============================================

      # Enhanced cache key strategy
      # @param name [String] The prompt name
      # @param state [Symbol, nil] The prompt state (:draft, :production, :archived)
      # @param version [Integer, nil] The prompt version number
      # @return [String] The cache key for the prompt
      def cache_key(name:, state: nil, version: nil)
        namespace = Observ.config.prompt_cache_namespace

        if version
          "#{namespace}:#{name}:version:#{version}"
        elsif state
          "#{namespace}:#{name}:state:#{state}"
        else
          "#{namespace}:#{name}:production"
        end
      end

      # ============================================
      # PROMPT FETCHING WITH ADVANCED CACHING
      # ============================================

      # Fetch single prompt with advanced caching
      # @param name [String] The prompt name
      # @param state [Symbol] The prompt state (default: :production)
      # @param version [Integer, nil] Specific version to fetch
      # @param fallback [String, nil] Fallback text if prompt not found
      # @return [Observ::Prompt, Observ::NullPrompt] The fetched prompt or NullPrompt with fallback
      def fetch(name:, state: :production, version: nil, fallback: nil)
        return fetch_from_db(name: name, state: state, version: version, fallback: fallback) unless caching_enabled?

        cache_key_value = cache_key(name: name, state: state, version: version)

        # Check if value exists in cache
        cache_hit = Rails.cache.exist?(cache_key_value)

        result = Rails.cache.fetch(cache_key_value, expires_in: Observ.config.prompt_cache_ttl) do
          fetch_from_db(name: name, state: state, version: version, fallback: fallback).tap do |prompt|
            # Only track cache miss for real prompts (not NullPrompt)
            if Observ.config.prompt_cache_monitoring_enabled && prompt && !prompt.is_a?(NullPrompt)
              track_cache_miss(name, state, version)
            end
          end
        end

        # Only track hit if it was actually in cache and is a real prompt
        if cache_hit && result && !result.is_a?(NullPrompt) && Observ.config.prompt_cache_monitoring_enabled
          track_cache_hit(name, state, version)
        end

        result
      rescue => e
        Rails.logger.error("Cache fetch failed for #{name}: #{e.message}")
        fetch_from_db(name: name, state: state, version: version, fallback: fallback)
      end

      # Fetch multiple prompts at once
      # @param names [Array<String>] The prompt names to fetch
      # @param state [Symbol] The prompt state (default: :production)
      # @return [Hash] Hash of prompt names to prompt objects
      def fetch_all(names:, state: :production)
        Prompt.where(name: names, state: state).index_by(&:name)
      end

      # ============================================
      # CACHE INVALIDATION
      # ============================================

      # Invalidate cache for a prompt
      # @param name [String] The prompt name
      # @param version [Integer, nil] Specific version to invalidate (nil = all states)
      # @return [Boolean] true if successful
      def invalidate_cache(name:, version: nil)
        keys = if version
          [cache_key(name: name, version: version)]
        else
          # Invalidate all state-based keys for this prompt
          [:draft, :production, :archived].map { |state| cache_key(name: name, state: state) }
        end

        keys.each { |key| Rails.cache.delete(key) }
        bump_cache_stamp(name: name)
        Rails.logger.info("Cache invalidated for #{name}#{version ? " v#{version}" : ""}")

        true
      end

      # ============================================
      # CACHE WARMING
      # ============================================

      # Warm cache for critical prompts
      # @param prompt_names [Array<String>, nil] Specific prompts to warm (nil = all critical)
      # @return [Hash] Hash with :success and :failed arrays
      def warm_cache(prompt_names = nil)
        names = prompt_names || critical_prompt_names

        results = { success: [], failed: [] }

        names.each do |name|
          begin
            # Fetch production version to warm cache
            fetch(name: name, state: :production)
            results[:success] << name
          rescue => e
            results[:failed] << { name: name, error: e.message }
            Rails.logger.error("Failed to warm cache for #{name}: #{e.message}")
          end
        end

        Rails.logger.info("Cache warming completed: #{results[:success].count} success, #{results[:failed].count} failed")
        results
      end

      def cache_stamp_key(name:)
        "#{Observ.config.prompt_cache_namespace}:#{name}:stamp"
      end

      def cache_stamp(name:)
        Rails.cache.read(cache_stamp_key(name: name))
      end

      def bump_cache_stamp(name:)
        Rails.cache.write(cache_stamp_key(name: name), Time.current.to_f)
      end

      # Get list of critical prompts (prompts used by agents)
      # @return [Array<String>] Array of prompt names
      def critical_prompt_names
        return Observ.config.prompt_cache_critical_prompts if Observ.config.prompt_cache_critical_prompts.any?

        # Auto-discover from production prompts
        Observ::Prompt.where(state: :production).distinct.pluck(:name)
      end

      private

      # ============================================
      # PRIVATE HELPER METHODS
      # ============================================

      # Check if caching is enabled
      # @return [Boolean]
      def caching_enabled?
        Observ.config.prompt_cache_ttl.present? && Observ.config.prompt_cache_ttl > 0
      end

      # Fetch prompt from database
      # @param name [String] The prompt name
      # @param state [Symbol] The prompt state
      # @param version [Integer, nil] Specific version to fetch
      # @param fallback [String, nil] Fallback text if not found
      # @return [Observ::Prompt, Observ::NullPrompt] The prompt or NullPrompt
      # @raise [PromptNotFoundError] If prompt not found and no fallback provided
      def fetch_from_db(name:, state:, version:, fallback:)
        query = Observ::Prompt.where(name: name)

        prompt = if version.present?
          query.find_by(version: version)
        else
          query.public_send(state).first
        end

        return prompt if prompt
        return NullPrompt.new(name: name, fallback_text: fallback) if fallback
        raise PromptNotFoundError, "Prompt '#{name}' not found"
      end
    end
  end
end
