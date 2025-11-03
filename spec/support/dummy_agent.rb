# frozen_string_literal: true

# Dummy agent class for testing PromptManager integration
# This simulates how a host application would integrate with Observ
class DummyAgent
  class_attribute :prompt_config, default: {}

  # Simulate BaseAgent's use_prompt_management method
  def self.use_prompt_management(enabled: true, prompt_name: nil, fallback: nil)
    self.prompt_config = {
      enabled: enabled,
      prompt_name: prompt_name || default_prompt_name,
      fallback: fallback || default_fallback_prompt
    }
  end

  def self.default_prompt_name
    name.underscore.tr("_/", "--") + "-system-prompt"
  end

  def self.default_fallback_prompt
    "You are a helpful AI assistant."
  end

  def self.prompt_management_enabled?
    Observ.config.prompt_management_enabled &&
    prompt_config[:enabled] != false
  end

  # Simulate BaseAgent's fetch_prompt method
  # This is the critical integration point that uses PromptManager
  def self.fetch_prompt(variables: {})
    return prompt_config[:fallback] unless prompt_management_enabled?

    start_time = Time.current

    begin
      # THIS IS THE CRITICAL CALL - if PromptManager modules are missing, this will fail
      prompt_template = Observ::PromptManager.fetch(
        name: prompt_config[:prompt_name],
        state: :production,
        fallback: prompt_config[:fallback]
      )

      # Log fetch result
      duration_ms = ((Time.current - start_time) * 1000).round(2)
      if prompt_template.version
        Rails.logger.info(
          "Prompt fetched for #{name}: #{prompt_config[:prompt_name]} " \
          "(version: #{prompt_template.version}, " \
          "duration: #{duration_ms}ms)"
        )
      else
        Rails.logger.info(
          "Using fallback prompt for #{name}: prompt '#{prompt_config[:prompt_name]}' not found " \
          "(duration: #{duration_ms}ms)"
        )
      end

      # Compile with variables (works for both Prompt and NullPrompt)
      if variables.any?
        prompt_template.compile(variables)
      else
        prompt_template.prompt
      end
    rescue => e
      Rails.logger.error(
        "Failed to fetch prompt for #{name}: #{e.message}\n" \
        "#{e.backtrace.first(5).join("\n")}"
      )
      prompt_config[:fallback]
    end
  end

  def self.system_prompt
    fetch_prompt(variables: {})
  end
end
