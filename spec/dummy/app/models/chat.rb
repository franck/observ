# frozen_string_literal: true

require "ostruct"

class Chat < ApplicationRecord
  include Observ::ChatEnhancements

  Response = Struct.new(:content, :input_tokens, :output_tokens, :raw, :model_id, keyword_init: true)

  has_many :messages, dependent: :destroy

  # Mock acts_as_chat for testing (normally provided by RubyLLM)
  def self.acts_as_chat
    true
  end

  def agent_class
    DummyAgent
  end

  def agent_class_name
    self[:agent_class_name] || DummyAgent.name
  end

  # Get the model from the agent's configuration
  def model
    return nil unless agent_class_name.present?

    begin
      agent_class.default_model
    rescue NameError
      nil
    end
  end

  def ask(message, **_options)
    messages.create!(role: :user, content: message)
    assistant_message = messages.create!(role: :assistant, content: "Echo: #{message}")

    Response.new(
      content: assistant_message.content,
      input_tokens: 0,
      output_tokens: 0,
      raw: OpenStruct.new(body: {}, headers: {}, status: 200),
      model_id: "dummy-model"
    )
  end

  # Simulates RubyLLM's complete method which generates a response
  # based on existing messages (without creating a new user message)
  def complete
    last_user_message = messages.where(role: :user).last
    content = last_user_message&.content || "empty"
    assistant_message = messages.create!(role: :assistant, content: "Echo: #{content}")

    yield OpenStruct.new(content: assistant_message.content) if block_given?

    Response.new(
      content: assistant_message.content,
      input_tokens: 0,
      output_tokens: 0,
      raw: OpenStruct.new(body: {}, headers: {}, status: 200),
      model_id: "dummy-model"
    )
  end

  def on_tool_call(*); end

  def on_tool_result(*); end

  def on_new_message(*); end

  def on_end_message(*); end

  # Stub methods for BaseAgent setup methods
  def with_instructions(instructions)
    self
  end

  def with_tools(*tools)
    self
  end

  def with_params(**params)
    self
  end
end
