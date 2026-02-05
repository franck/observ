# frozen_string_literal: true

FactoryBot.define do
  factory :chat do
    sequence(:title) { |n| "Chat #{n}" }
    agent_class_name { "DummyAgent" }
  end
end
