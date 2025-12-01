module Observ
  class MessagesController < ApplicationController
    before_action :set_chat

    def create
      return unless content.present?

      # Create user message synchronously so it appears immediately
      @message = @chat.messages.create!(role: :user, content: content)

      # Enqueue job to get assistant response (will broadcast when complete)
      ChatResponseJob.perform_later(@chat.id, @message.id)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to chat_path(@chat) }
      end
    end

    private

    def set_chat
      @chat = Chat.find(params[:chat_id])
    end

    def content
      params[:message][:content]
    end
  end
end
