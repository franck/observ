module Observ
  class ChatsController < ApplicationController
    before_action :set_chat, only: [ :show ]

    def index
      @chats = ::Chat.order(created_at: :desc)
    end

    def new
      @chat = ::Chat.new
    end

    def create
      @chat = ::Chat.new(params_chat)

      if @chat.save
        redirect_to chat_path(@chat), notice: "Chat was successfully created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      @message = @chat.messages.build
    end

    private

    def params_chat
      params.require(:chat).permit(:model, :agent_class_name).with_defaults(model: RubyLLM.config.default_model)
    end

    def set_chat
      @chat = ::Chat.find(params[:id])
    end

    def model
      params[:chat][:model].presence
    end

    def prompt
      params[:chat][:prompt]
    end
  end
end
