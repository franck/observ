# frozen_string_literal: true

module Observ
  # Concern for enhancing Message models with observability and broadcasting support
  # This provides the integration between your Message model and the Observ system
  #
  # Usage:
  #   class Message < ApplicationRecord
  #     include Observ::MessageEnhancements
  #   end
  module MessageEnhancements
    extend ActiveSupport::Concern

    included do
      include Observ::TraceAssociation

      # Broadcasts message updates to the chat channel
      # Override the lambda if your chat_id attribute has a different name
      broadcasts_to ->(message) { "chat_#{message.chat_id}" }, partial: "observ/messages/message"
    end

    # Broadcast a content chunk to the message
    # Useful for streaming responses
    def broadcast_append_chunk(content)
      broadcast_append_to "chat_#{chat_id}",
        target: "message_#{id}_content",
        partial: "observ/messages/content",
        locals: { content: content }
    end
  end
end
