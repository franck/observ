# frozen_string_literal: true

module Observ
  module ChatsHelper
    # Returns formatted agent selection options for the chat form
    #
    # This helper provides agent selection options for use in select dropdowns.
    # The options are memoized per request to avoid redundant agent discovery.
    #
    # Usage in views:
    #   <%= form.select :agent_class_name, agent_select_options, {}, class: "observ-select" %>
    #
    # @return [Array<Array<String>>] options array for Rails select helper
    #   Format: [["Display Name", "ClassName"], ...]
    def agent_select_options
      @agent_select_options ||= AgentSelectionService.options
    end

    # Returns a map of agent class names to their prompt names
    #
    # This helper identifies which agents use prompt management and maps them
    # to their configured prompt names. Used by the chat form's Stimulus controller
    # to dynamically show/hide the prompt version selector.
    #
    # Usage in views:
    #   data: {
    #     observ__chat_form_agents_with_prompts_value: agents_with_prompts_map.to_json
    #   }
    #
    # @return [Hash<String, String>] Hash mapping agent class names to prompt names
    #   Format: { "AgentClassName" => "prompt-name", ... }
    def agents_with_prompts_map
      @agents_with_prompts_map ||= begin
        Observ::AgentProvider.all_agents.each_with_object({}) do |agent_class, hash|
          # Check if agent includes PromptManagement and has prompt management enabled
          if agent_class.included_modules.include?(Observ::PromptManagement) &&
             agent_class.respond_to?(:prompt_management_enabled?) &&
             agent_class.prompt_management_enabled?
            # Extract prompt name from agent's configuration
            prompt_name = agent_class.prompt_config[:prompt_name]
            hash[agent_class.name] = prompt_name if prompt_name.present?
          end
        end
      end
    end
  end
end
