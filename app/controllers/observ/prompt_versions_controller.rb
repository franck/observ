module Observ
  class PromptVersionsController < ApplicationController
    before_action :set_prompt_name
    before_action :set_prompt

    # GET /observ/prompts/:prompt_id/versions/:id
    def show
      redirect_to prompt_path(@prompt_name, version: @prompt.version)
    end

    # POST /observ/prompts/:prompt_id/versions/:id/promote
    def promote
      unless @prompt.draft?
        respond_to do |format|
          format.html do
            redirect_to prompt_path(@prompt_name, version: @prompt.version),
              alert: "Only draft prompts can be promoted"
          end
          format.json { render json: { error: "Only draft prompts can be promoted" }, status: :unprocessable_entity }
        end
        return
      end

      begin
        Observ::PromptManager.promote(name: @prompt_name, version: @prompt.version)

        respond_to do |format|
          format.html do
            redirect_to prompt_path(@prompt_name),
              notice: "Version #{@prompt.version} promoted to production"
          end
          format.json { render json: { success: true, message: "Promoted to production" } }
        end
      rescue StandardError => e
        respond_to do |format|
          format.html do
            redirect_to prompt_path(@prompt_name, version: @prompt.version),
              alert: e.message
          end
          format.json { render json: { error: e.message }, status: :unprocessable_entity }
        end
      end
    end

    # POST /observ/prompts/:prompt_id/versions/:id/demote
    def demote
      unless @prompt.production?
        respond_to do |format|
          format.html do
            redirect_to prompt_path(@prompt_name, version: @prompt.version),
              alert: "Only production prompts can be demoted"
          end
          format.json { render json: { error: "Only production prompts can be demoted" }, status: :unprocessable_entity }
        end
        return
      end

      begin
        Observ::PromptManager.demote(name: @prompt_name, version: @prompt.version)

        respond_to do |format|
          format.html do
            redirect_to prompt_path(@prompt_name),
              notice: "Version #{@prompt.version} demoted to archived"
          end
          format.json { render json: { success: true, message: "Demoted to archived" } }
        end
      rescue StandardError => e
        respond_to do |format|
          format.html do
            redirect_to prompt_path(@prompt_name, version: @prompt.version),
              alert: e.message
          end
          format.json { render json: { error: e.message }, status: :unprocessable_entity }
        end
      end
    end

    # POST /observ/prompts/:prompt_id/versions/:id/restore
    def restore
      unless @prompt.archived?
        respond_to do |format|
          format.html do
            redirect_to prompt_path(@prompt_name, version: @prompt.version),
              alert: "Only archived prompts can be restored"
          end
          format.json { render json: { error: "Only archived prompts can be restored" }, status: :unprocessable_entity }
        end
        return
      end

      begin
        Observ::PromptManager.restore(name: @prompt_name, version: @prompt.version)

        respond_to do |format|
          format.html do
            redirect_to prompt_path(@prompt_name),
              notice: "Version #{@prompt.version} restored to production"
          end
          format.json { render json: { success: true, message: "Restored to production" } }
        end
      rescue StandardError => e
        respond_to do |format|
          format.html do
            redirect_to prompt_path(@prompt_name, version: @prompt.version),
              alert: e.message
          end
          format.json { render json: { error: e.message }, status: :unprocessable_entity }
        end
      end
    end

    # POST /observ/prompts/:prompt_id/versions/:id/clone
    def clone
      # Production and archived prompts are immutable - clone to draft for editing
      begin
        new_prompt = Observ::PromptManager.create(
          name: @prompt_name,
          prompt: @prompt.prompt,
          config: @prompt.config,
          commit_message: "Cloned from version #{@prompt.version}",
          created_by: current_user_identifier,
          promote_to_production: false
        )

        redirect_to edit_prompt_path(@prompt_name, version: new_prompt.version),
          notice: "Created editable draft (v#{new_prompt.version}) from version #{@prompt.version}"
      rescue ActiveRecord::RecordInvalid, StandardError => e
        redirect_to prompt_path(@prompt_name, version: @prompt.version),
          alert: e.message
      end
    end

    private

    def set_prompt_name
      @prompt_name = params[:prompt_id]
    end

    def set_prompt
      @prompt = Observ::Prompt.find(params[:id])
    end

    def current_user_identifier
      "system" # Default fallback
    end
  end
end
