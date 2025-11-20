module Observ
  class ChatsController < ApplicationController
    before_action :set_chat, only: [ :show ]

    def index
      @chats = ::Chat.order(created_at: :desc)
        .page(params[:page])
        .per(Observ.config.pagination_per_page)
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
      params.require(:chat).permit(:agent_class_name)
    end

    def set_chat
      @chat = ::Chat.find(params[:id])
    end
  end
end
