require "rails_helper"

RSpec.describe "Observ::PromptsController", type: :request do
  describe "GET /observ/prompts" do
    it "displays list of prompts" do
      create(:observ_prompt, :production, name: "test-prompt-1")
      create(:observ_prompt, :production, name: "test-prompt-2")

      get observ_prompts_path

      expect(response).to be_successful
      expect(response.body).to include("test-prompt-1")
      expect(response.body).to include("test-prompt-2")
    end

    it "filters by search query" do
      create(:observ_prompt, :production, name: "research-prompt")
      create(:observ_prompt, :production, name: "chat-prompt")

      get observ_prompts_path, params: { search: "research" }

      expect(response).to be_successful
      expect(response.body).to include("research-prompt")
      expect(response.body).not_to include("chat-prompt")
    end

    it "filters by state" do
      create(:observ_prompt, :draft, name: "draft-prompt")
      create(:observ_prompt, :production, name: "prod-prompt")

      get observ_prompts_path, params: { state: "draft" }

      expect(response).to be_successful
      expect(response.body).to include("draft-prompt")
    end
  end

  describe "GET /observ/prompts/new" do
    it "displays new prompt form" do
      get new_observ_prompt_path

      expect(response).to be_successful
      expect(response.body).to include("Create New Prompt")
    end

    it "pre-fills name when provided" do
      get new_observ_prompt_path, params: { name: "my-custom-prompt" }

      expect(response).to be_successful
      expect(response.body).to include("my-custom-prompt")
    end

    it "pre-fills content from existing version" do
      existing = create(:observ_prompt, name: "test-prompt", version: 1, prompt: "Existing content")

      get new_observ_prompt_path, params: { name: "test-prompt", from_version: 1 }

      expect(response).to be_successful
      expect(response.body).to include("Existing content")
    end
  end

  describe "GET /observ/prompts/:id" do
    let!(:prompt) { create(:observ_prompt, :production, name: "test-prompt") }

    it "displays prompt details" do
      get observ_prompt_path("test-prompt")

      expect(response).to be_successful
      expect(response.body).to include("test-prompt")
      # Prompt content is HTML-escaped and highlighted, so check for parts of it
      expect(response.body).to include("You are a")
      expect(response.body).to include("role")
      expect(response.body).to include("date")
    end

    it "escapes HTML/XML tags in prompt content" do
      prompt_with_xml = create(:observ_prompt, :production,
        name: "xml-prompt",
        prompt: "<system>\nYou are a helpful assistant.\nUse {{tools}} when needed.\n</system>\n\n<user>{{query}}</user>"
      )

      get observ_prompt_path("xml-prompt")

      expect(response).to be_successful
      # XML tags should be escaped and visible
      expect(response.body).to include("&lt;system&gt;")
      expect(response.body).to include("&lt;/system&gt;")
      expect(response.body).to include("&lt;user&gt;")
      expect(response.body).to include("&lt;/user&gt;")
      # Variables should be highlighted
      expect(response.body).to include("{{tools}}")
      expect(response.body).to include("{{query}}")
    end

    it "displays specific version when requested" do
      draft = create(:observ_prompt, :draft, name: "test-prompt", version: 2)

      get observ_prompt_path("test-prompt", version: 2)

      expect(response).to be_successful
      expect(response.body).to include("Currently viewing version 2")
    end

    it "defaults to production version" do
      _draft = create(:observ_prompt, :draft, name: "test-prompt", version: 2)

      get observ_prompt_path("test-prompt")

      expect(response).to be_successful
      expect(response.body).to include("Currently viewing version 1")
    end

    it "redirects when prompt not found" do
      get observ_prompt_path("nonexistent")

      expect(response).to redirect_to(observ_prompts_path)
      follow_redirect!
      expect(response.body).to include("Prompt not found")
    end
  end

  describe "POST /observ/prompts" do
    it "creates new prompt" do
      expect {
        post observ_prompts_path, params: {
          observ_prompt_form: {
            name: "new-prompt",
            prompt: "Test content",
            commit_message: "Initial version"
          }
        }
      }.to change(Observ::Prompt, :count).by(1)

      expect(response).to redirect_to(observ_prompt_path("new-prompt"))
      follow_redirect!
      expect(response.body).to include("created successfully")
    end

    it "promotes to production when requested" do
      post observ_prompts_path, params: {
        observ_prompt_form: {
          name: "new-prompt",
          prompt: "Test content",
          promote_to_production: "1"
        }
      }

      prompt = Observ::Prompt.find_by(name: "new-prompt")
      expect(prompt.state).to eq("production")
    end

    it "handles validation errors" do
      post observ_prompts_path, params: {
        observ_prompt_form: {
          name: "",
          prompt: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("error")
    end

    it "parses JSON configuration" do
      post observ_prompts_path, params: {
        observ_prompt_form: {
          name: "new-prompt",
          prompt: "Test content",
          config: '{"model": "gpt-4o", "temperature": 0.7}'
        }
      }

      prompt = Observ::Prompt.find_by(name: "new-prompt")
      expect(prompt.config["model"]).to eq("gpt-4o")
      expect(prompt.config["temperature"]).to eq(0.7)
    end

    it "handles invalid JSON in config" do
      post observ_prompts_path, params: {
        observ_prompt_form: {
          name: "new-prompt",
          prompt: "Test content",
          config: "{invalid json}"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be valid JSON")
    end
  end

  describe "GET /observ/prompts/:id/edit" do
    it "displays edit form for draft prompts" do
      draft = create(:observ_prompt, :draft, name: "test-prompt")

      get edit_observ_prompt_path("test-prompt", version: draft.version)

      expect(response).to be_successful
      expect(response.body).to include("Edit Prompt Draft")
    end

    it "redirects when editing production prompt" do
      prompt = create(:observ_prompt, :production, name: "test-prompt")

      get edit_observ_prompt_path("test-prompt", version: prompt.version)

      expect(response).to redirect_to(observ_prompt_path("test-prompt"))
      follow_redirect!
      expect(response.body).to include("Only draft prompts can be edited")
    end
  end

  describe "PATCH /observ/prompts/:id" do
    let!(:draft) { create(:observ_prompt, :draft, name: "test-prompt") }

    it "updates draft prompt" do
      patch observ_prompt_path("test-prompt", version: draft.version), params: {
        observ_prompt: {
          prompt: "Updated content"
        }
      }

      expect(draft.reload.prompt).to eq("Updated content")
      expect(response).to redirect_to(observ_prompt_path("test-prompt", version: draft.version))
    end

    it "prevents editing production prompts" do
      prompt = create(:observ_prompt, :production, name: "prod-prompt")

      patch observ_prompt_path("prod-prompt", version: prompt.version), params: {
        observ_prompt: { prompt: "New content" }
      }

      expect(response).to redirect_to(observ_prompt_path("prod-prompt"))
      expect(prompt.reload.prompt).not_to eq("New content")
    end

    it "handles validation errors" do
      patch observ_prompt_path("test-prompt", version: draft.version), params: {
        observ_prompt: {
          prompt: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /observ/prompts/:id" do
    it "deletes draft prompts" do
      draft = create(:observ_prompt, :draft, name: "test-prompt")

      expect {
        delete observ_prompt_path("test-prompt", version: draft.version)
      }.to change(Observ::Prompt, :count).by(-1)

      expect(response).to redirect_to(observ_prompts_path)
    end

    it "prevents deleting production prompts" do
      prompt = create(:observ_prompt, :production, name: "prod-prompt")

      expect {
        delete observ_prompt_path("prod-prompt", version: prompt.version)
      }.not_to change(Observ::Prompt, :count)

      expect(response).to redirect_to(observ_prompt_path("prod-prompt"))
      follow_redirect!
      expect(response.body).to include("Cannot delete production")
    end

    it "deletes archived prompts" do
      archived = create(:observ_prompt, :archived, name: "test-prompt")

      expect {
        delete observ_prompt_path("test-prompt", version: archived.version)
      }.to change(Observ::Prompt, :count).by(-1)
    end
  end

  describe "GET /observ/prompts/:id/versions" do
    it "displays version history" do
      create(:observ_prompt, :production, name: "test-prompt", version: 1)
      create(:observ_prompt, :draft, name: "test-prompt", version: 2)

      get versions_observ_prompt_path("test-prompt")

      expect(response).to be_successful
      expect(response.body).to include("Version History")
      expect(response.body).to include("Version 1")
      expect(response.body).to include("Version 2")
    end
  end

  describe "GET /observ/prompts/:id/compare" do
    let!(:v1) { create(:observ_prompt, :production, name: "test-prompt", version: 1, prompt: "Version 1") }
    let!(:v2) { create(:observ_prompt, :draft, name: "test-prompt", version: 2, prompt: "Version 2") }

    it "displays version comparison" do
      get compare_observ_prompt_path("test-prompt", from: 1, to: 2)

      expect(response).to be_successful
      expect(response.body).to include("Compare Versions")
      expect(response.body).to include("Version 1")
      expect(response.body).to include("Version 2")
    end

    it "redirects when versions not specified" do
      get compare_observ_prompt_path("test-prompt")

      expect(response).to redirect_to(versions_observ_prompt_path("test-prompt"))
    end

    it "redirects when version not found" do
      get compare_observ_prompt_path("test-prompt", from: 1, to: 999)

      expect(response).to redirect_to(versions_observ_prompt_path("test-prompt"))
    end
  end
end
