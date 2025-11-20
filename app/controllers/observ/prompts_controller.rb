module Observ
  class PromptsController < ApplicationController
    before_action :set_prompt_name, only: [ :show, :edit, :update, :destroy, :versions, :compare ]
    before_action :set_prompt, only: [ :edit, :update, :destroy ]

    # GET /observ/prompts
    def index
      @prompts = Observ::Prompt.select(:name)
        .distinct
        .order(:name)

      # Apply search filter
      if params[:search].present?
        @prompts = @prompts.where("name LIKE ? COLLATE NOCASE", "%#{params[:search]}%")
      end

      # Apply state filter
      if params[:state].present?
        @prompts = @prompts.where(state: params[:state])
      end

      @prompts = @prompts.page(params[:page]).per(Observ.config.pagination_per_page)

      # Enrich with metadata for display
      @prompt_data = @prompts.map do |prompt|
        latest = Observ::Prompt.where(name: prompt.name).order(version: :desc).first
        production = Observ::Prompt.where(name: prompt.name, state: :production).first

        {
          name: prompt.name,
          total_versions: Observ::Prompt.where(name: prompt.name).count,
          production_version: production&.version,
          latest_version: latest.version,
          latest_state: latest.state,
          last_updated: latest.updated_at,
          has_draft: Observ::Prompt.where(name: prompt.name, state: :draft).exists?
        }
      end
    end

    # GET /observ/prompts/new
    def new
      @form = Observ::PromptForm.new(
        name: params[:name],
        from_version: params[:from_version]
      )
    end

    # POST /observ/prompts
    def create
      @form = Observ::PromptForm.new(form_params)
      @form.created_by = current_user_identifier

      if @form.save
        redirect_to prompt_path(@form.persisted_prompt.name),
          notice: "Prompt created successfully (v#{@form.persisted_prompt.version})"
      else
        render :new, status: :unprocessable_content
      end
    end

    # GET /observ/prompts/:id
    def show
      # Get production version by default, or latest version if no production
      @prompt = Observ::Prompt.where(name: @prompt_name, state: :production).first ||
                Observ::Prompt.where(name: @prompt_name).order(version: :desc).first

      unless @prompt
        redirect_to prompts_path, alert: "Prompt not found"
        return
      end

      # Load specific version if requested
      if params[:version].present?
        @prompt = Observ::Prompt.find_by(name: @prompt_name, version: params[:version])
        unless @prompt
          redirect_to prompt_path(@prompt_name), alert: "Version not found"
          return
        end
      end

      @all_versions = Observ::Prompt.where(name: @prompt_name).order(version: :desc)
      @production_version = @all_versions.find(&:production?)
    end

    # GET /observ/prompts/:id/edit
    def edit
      # Only draft prompts can be edited
      unless @prompt.draft?
        redirect_to prompt_path(@prompt_name),
          alert: "Only draft prompts can be edited. Clone this version to create an editable draft."
      end
    end

    # PATCH /observ/prompts/:id
    def update
      unless @prompt.draft?
        redirect_to prompt_path(@prompt_name),
          alert: "Only draft prompts can be edited"
        return
      end

      # Parse config JSON string before updating
      update_params = prompt_params.except(:name, :version, :promote_to_production)
      if update_params[:config].present?
        update_params[:config] = parse_config(update_params[:config])
      end

      if @prompt.update(update_params)
        redirect_to prompt_path(@prompt_name, version: @prompt.version),
          notice: "Prompt updated successfully"
      else
        render :edit, status: :unprocessable_content
      end
    end

    # DELETE /observ/prompts/:id
    def destroy
      # Can only delete draft and archived prompts
      if @prompt.production?
        redirect_to prompt_path(@prompt_name),
          alert: "Cannot delete production prompts"
        return
      end

      @prompt.destroy
      redirect_to prompts_path, notice: "Prompt version #{@prompt.version} deleted"
    end

    # GET /observ/prompts/:id/versions
    def versions
      @versions = Observ::Prompt.where(name: @prompt_name).order(version: :desc)
      @production_version = @versions.find(&:production?)

      respond_to do |format|
        format.html # Render the HTML view
        format.json do
          render json: @versions.as_json(only: [ :version, :state, :commit_message, :created_at ])
        end
      end
    end

    # GET /observ/prompts/:id/compare?from=1&to=2
    def compare
      @from_version = Observ::Prompt.find_by(name: @prompt_name, version: params[:from])
      @to_version = Observ::Prompt.find_by(name: @prompt_name, version: params[:to])

      unless @from_version && @to_version
        redirect_to versions_prompt_path(@prompt_name),
          alert: "Both versions must be specified"
        return
      end

      @diff = calculate_diff(@from_version.prompt, @to_version.prompt)
    end

    private

    def set_prompt_name
      @prompt_name = params[:id] || params[:name]
    end

    def set_prompt
      version = params[:version] || Observ::Prompt.where(name: @prompt_name, state: :draft).maximum(:version)
      @prompt = Observ::Prompt.find_by!(name: @prompt_name, version: version)
    end

    def prompt_params
      params.require(:observ_prompt).permit(
        :name, :prompt, :config, :commit_message, :promote_to_production
      )
    end

    def form_params
      params.require(:observ_prompt_form).permit(
        :name, :prompt, :config, :commit_message, :promote_to_production, :from_version
      )
    end

    def parse_config(config_string)
      return {} if config_string.blank?
      JSON.parse(config_string)
    rescue JSON::ParserError
      {}
    end

    def current_user_identifier
      # Implement based on your authentication system
      "system" # Default fallback
    end

    def calculate_diff(text1, text2)
      # Simple line-by-line diff
      # In production, consider using gems like 'diffy' or 'diff-lcs'
      lines1 = text1.split("\n")
      lines2 = text2.split("\n")

      {
        removed: lines1 - lines2,
        added: lines2 - lines1,
        common: lines1 & lines2
      }
    end
  end
end
