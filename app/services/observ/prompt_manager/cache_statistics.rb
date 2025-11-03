# frozen_string_literal: true

module Observ
  class PromptManager
    # Concern for cache statistics tracking and reporting.
    # Handles hit/miss tracking and statistics aggregation.
    module CacheStatistics
      # ============================================
      # CACHE STATISTICS
      # ============================================

      # Get cache statistics for a prompt
      # @param name [String] The prompt name
      # @return [Hash] Statistics hash with :name, :hits, :misses, :total, :hit_rate
      def cache_stats(name)
        hits_key = "#{Observ.config.prompt_cache_namespace}:stats:#{name}:hits"
        misses_key = "#{Observ.config.prompt_cache_namespace}:stats:#{name}:misses"

        hits = Rails.cache.read(hits_key) || 0
        misses = Rails.cache.read(misses_key) || 0
        total = hits + misses
        hit_rate = total > 0 ? (hits.to_f / total * 100).round(2) : 0

        {
          name: name,
          hits: hits,
          misses: misses,
          total: total,
          hit_rate: hit_rate
        }
      end

      # Clear all cache statistics
      # @return [Boolean] true if successful
      def clear_stats
        Observ::Prompt.distinct.pluck(:name).each do |name|
          hits_key = "#{Observ.config.prompt_cache_namespace}:stats:#{name}:hits"
          misses_key = "#{Observ.config.prompt_cache_namespace}:stats:#{name}:misses"

          Rails.cache.delete(hits_key)
          Rails.cache.delete(misses_key)
        end

        Rails.logger.info("Cache statistics cleared")
        true
      end

      private

      # ============================================
      # PRIVATE TRACKING METHODS
      # ============================================

      # Track a cache hit
      # @param name [String] The prompt name
      # @param state [Symbol] The prompt state
      # @param version [Integer, nil] The prompt version
      def track_cache_hit(name, state, version)
        cache_stats_key = "#{Observ.config.prompt_cache_namespace}:stats:#{name}:hits"

        # Use Rails cache for atomic operation
        current_value = Rails.cache.read(cache_stats_key) || 0
        Rails.cache.write(cache_stats_key, current_value + 1, expires_in: 1.day)
      rescue => e
        Rails.logger.error("Failed to track cache hit: #{e.message}")
      end

      # Track a cache miss
      # @param name [String] The prompt name
      # @param state [Symbol] The prompt state
      # @param version [Integer, nil] The prompt version
      def track_cache_miss(name, state, version)
        cache_stats_key = "#{Observ.config.prompt_cache_namespace}:stats:#{name}:misses"

        current_value = Rails.cache.read(cache_stats_key) || 0
        Rails.cache.write(cache_stats_key, current_value + 1, expires_in: 1.day)
      rescue => e
        Rails.logger.error("Failed to track cache miss: #{e.message}")
      end
    end
  end
end
