# frozen_string_literal: true

module Observ
  # Service for providing agent selection options in the Observ domain
  #
  # This service encapsulates the workflow of:
  #   1. Discovering available agents (via Observ::AgentProvider)
  #   2. Formatting them for UI presentation (via AgentSelectPresenter)
  #
  # This service acts as the single entry point for agent selection,
  # hiding the complexity of agent discovery and presentation from
  # controllers and views.
  #
  # Usage in controllers:
  #   @agent_select_options = Observ::AgentSelectionService.options
  #
  # Usage in helpers:
  #   def agent_select_options
  #     Observ::AgentSelectionService.options
  #   end
  #
  # Example output:
  #   [
  #     ["Default Agent", ""],
  #     ["Deep Research", "DeepResearchAgent"],
  #     ["Simple Research", "ResearchAgent"]
  #   ]
  class AgentSelectionService
    class << self
      # Returns formatted select options for agent selection dropdown
      #
      # This method orchestrates the entire agent selection workflow:
      # - Discovers all available agents
      # - Formats them for use in Rails select helpers
      #
      # @return [Array<Array<String>>] options array for Rails select helper
      #   Format: [["Display Name", "ClassName"], ...]
      def options
        AgentSelectPresenter.options(agents: Observ::AgentProvider.all_agents)
      end

      # Returns all available agents (pass-through to Observ::AgentProvider)
      #
      # Useful when you need the raw agent classes instead of formatted options.
      # For most UI purposes, prefer using .options instead.
      #
      # @return [Array<Class>] array of agent classes implementing Observ::AgentSelectable
      def all_agents
        Observ::AgentProvider.all_agents
      end
    end
  end
end
