# frozen_string_literal: true

# Dummy agent class for testing PromptManager integration
# This simulates how a host application would integrate with Observ
class DummyAgent < BaseAgent
  include Observ::PromptManagement
  include Observ::AgentSelectable

  def self.system_prompt
    "You are a helpful assistant."
  end

  def self.default_model
    "gpt-4o-mini"
  end

  def self.default_model_parameters
    { temperature: 0.5 }
  end

  def self.display_name
    "Dummy Agent"
  end

  def self.description
    "Test agent used in specs"
  end
end
