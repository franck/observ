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
  end
end
