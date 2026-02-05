module Observ
  class ChatsController < ApplicationController
    before_action :set_chat, only: [:show]

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

      # Set prompt name from agent if applicable
      set_prompt_info_from_agent

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
      params.require(:chat).permit(:agent_class_name, :prompt_version)
    end

    def set_prompt_info_from_agent
      return unless @chat.agent_class_name.present?

      agent_class = @chat.agent_class_name.constantize

      # Check if agent uses prompt management
      if agent_class.included_modules.include?(Observ::PromptManagement) &&
         agent_class.respond_to?(:prompt_management_enabled?) &&
         agent_class.prompt_management_enabled?
        @chat.prompt_name = agent_class.prompt_config[:prompt_name]
      end
    rescue NameError => e
      Rails.logger.warn("Agent class not found: #{@chat.agent_class_name} - #{e.message}")
      # Agent class not found, continue without setting prompt_name
    end

    def set_chat
      @chat = ::Chat.find(params[:id])
    end
  end
end
