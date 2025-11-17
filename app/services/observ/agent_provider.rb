# frozen_string_literal: true

module Observ
  # Service for discovering and providing available agents
  # This is the ONLY class that knows how to discover agents in the application
  #
  # Responsibilities:
  #   - Loading agent files in development mode (via Zeitwerk)
  #   - Discovering all agents that implement Observ::AgentSelectable
  #   - Sorting and filtering agents
  #
  # The Observ domain queries this service to get available agents,
  # maintaining clean separation between domains.
  #
  # Configuration:
  #   You can customize the agent discovery path via configuration:
  #
  #   Observ.configure do |config|
  #     config.agent_path = Rails.root.join("lib", "my_agents")
  #   end
  #
  # Usage:
  #   agents = Observ::AgentProvider.all_agents
  #   # => [LanguageDetectionAgent, MoodDetectionAgent, ...]
  class AgentProvider
    class << self
      # Returns all available agents that implement the Observ::AgentSelectable interface
      # Agents are sorted alphabetically by display_name
      #
      # @return [Array<Class>] array of agent classes
      def all_agents
        ensure_agents_loaded

        BaseAgent.descendants
                 .select { |agent_class| agent_class.include?(Observ::AgentSelectable) }
                 .sort_by(&:display_name)
      end

      private

      # Ensures all agent files are loaded in development mode
      # Uses Zeitwerk's eager_load_dir for thread-safe, Rails-idiomatic loading
      # In production, eager loading handles this automatically (this becomes a no-op)
      def ensure_agents_loaded
        return if Rails.application.config.eager_load

        agent_path = Observ.config.agent_path || default_agent_path
        Rails.autoloaders.main.eager_load_dir(agent_path) if agent_path.exist?
      end

      # Default path where agents are located
      # @return [Pathname] the default agent path
      def default_agent_path
        Rails.root.join("app", "agents")
      end
    end
  end
end
