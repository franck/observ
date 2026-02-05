# Presenter for agent selection in the Observ domain
#
# This presenter receives agents via dependency injection and formats them
# for display in select dropdowns. It has NO knowledge of:
#   - How agents are discovered
#   - Where agent files are located
#   - The BaseAgent class hierarchy
#
# It only knows about the AgentSelectable interface that agents must implement.
#
# Usage with dependency injection (recommended):
#   agents = Observ::AgentProvider.all_agents
#   presenter = Observ::AgentSelectPresenter.new(agents: agents)
#   presenter.options
#   # => [["Default Agent", ""], ["Deep Research", "DeepResearchAgent"], ...]
#
# Usage with convenience class method:
#   Observ::AgentSelectPresenter.options
#   # => [["Default Agent", ""], ["Deep Research", "DeepResearchAgent"], ...]
module Observ
  class AgentSelectPresenter
    attr_reader :agents

    # Initialize with dependency injection
    # @param agents [Array<Class>] array of agent classes implementing AgentSelectable
    def initialize(agents:)
      @agents = agents
    end

    # Returns formatted options for Rails select helper
    # Format: [[display_name, identifier], ...]
    # @return [Array<Array<String>>] options array for select dropdown
    def options
      [default_option] + agent_options
    end

    # Convenience class method that injects agents from Observ::AgentProvider
    # Useful when you don't need to filter or transform agents
    # @param agents [Array<Class>] optional array of agents (defaults to Observ::AgentProvider.all_agents)
    # @return [Array<Array<String>>] options array for select dropdown
    def self.options(agents: Observ::AgentProvider.all_agents)
      new(agents: agents).options
    end

    private

    # Default option for "no agent selected" state
    # @return [Array<String>] the default option
    def default_option
      ["Default Agent", ""]
    end

    # Maps agents to [display_name, identifier] pairs
    # @return [Array<Array<String>>] agent options
    def agent_options
      agents.map { |agent| [agent.display_name, agent.agent_identifier] }
    end
  end
end
