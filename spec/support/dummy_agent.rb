# frozen_string_literal: true

# Dummy agent class for testing PromptManager integration
# This simulates how a host application would integrate with Observ
class DummyAgent
  include Observ::PromptManagement

  def self.default_model
    "gpt-4o-mini"
  end

  def self.default_model_parameters
    { temperature: 0.5 }
  end
end
