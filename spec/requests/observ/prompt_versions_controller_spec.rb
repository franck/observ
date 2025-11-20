require "rails_helper"

RSpec.describe "Observ::PromptVersionsController", type: :request do
  describe "GET /observ/prompts/:prompt_id/versions/:id" do
    it "redirects to prompt show with version parameter" do
      prompt = create(:observ_prompt, :production, name: "test-prompt")

      get observ_prompt_version_path("test-prompt", prompt)

      expect(response).to redirect_to(observ_prompt_path("test-prompt", version: prompt.version))
    end
  end

  describe "POST /observ/prompts/:prompt_id/versions/:id/promote" do
    it "promotes draft to production" do
      draft = create(:observ_prompt, :draft, name: "promote-test-1")

      post promote_observ_prompt_version_path("promote-test-1", draft)

      expect(draft.reload.state).to eq("production")
      expect(response).to redirect_to(observ_prompt_path("promote-test-1"))
      follow_redirect!
      expect(response.body).to include("promoted to production")
    end

    it "demotes existing production version" do
      production = create(:observ_prompt, :production, name: "promote-test-2", version: 1)
      draft = create(:observ_prompt, :draft, name: "promote-test-2", version: 2)

      post promote_observ_prompt_version_path("promote-test-2", draft)

      expect(production.reload.state).to eq("archived")
      expect(draft.reload.state).to eq("production")
    end

    it "prevents promoting non-draft prompts" do
      production = create(:observ_prompt, :production, name: "promote-test-3")

      post promote_observ_prompt_version_path("promote-test-3", production)

      expect(response).to redirect_to(observ_prompt_path("promote-test-3", version: production.version))
      follow_redirect!
      expect(response.body).to include("Only draft prompts can be promoted")
    end

    it "supports JSON response" do
      draft = create(:observ_prompt, :draft, name: "promote-test-4")

      post promote_observ_prompt_version_path("promote-test-4", draft), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end

    it "returns error for non-draft in JSON" do
      production = create(:observ_prompt, :production, name: "promote-test-5")

      post promote_observ_prompt_version_path("promote-test-5", production), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to be_present
    end
  end

  describe "POST /observ/prompts/:prompt_id/versions/:id/demote" do
    it "demotes production to archived" do
      production = create(:observ_prompt, :production, name: "demote-test-1")

      post demote_observ_prompt_version_path("demote-test-1", production)

      expect(production.reload.state).to eq("archived")
      expect(response).to redirect_to(observ_prompt_path("demote-test-1"))
      follow_redirect!
      expect(response.body).to include("demoted to archived")
    end

    it "prevents demoting non-production prompts" do
      draft = create(:observ_prompt, :draft, name: "demote-test-2")

      post demote_observ_prompt_version_path("demote-test-2", draft)

      expect(response).to redirect_to(observ_prompt_path("demote-test-2", version: draft.version))
      follow_redirect!
      expect(response.body).to include("Only production prompts can be demoted")
      expect(draft.reload.state).to eq("draft")
    end

    it "supports JSON response" do
      production = create(:observ_prompt, :production, name: "demote-test-3")

      post demote_observ_prompt_version_path("demote-test-3", production), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end
  end

  describe "POST /observ/prompts/:prompt_id/versions/:id/restore" do
    it "restores archived to production" do
      archived = create(:observ_prompt, :archived, name: "restore-test-1")

      post restore_observ_prompt_version_path("restore-test-1", archived)

      expect(archived.reload.state).to eq("production")
      expect(response).to redirect_to(observ_prompt_path("restore-test-1"))
      follow_redirect!
      expect(response.body).to include("restored to production")
    end

    it "demotes existing production when restoring" do
      production = create(:observ_prompt, :production, name: "restore-test-2", version: 1)
      archived = create(:observ_prompt, :archived, name: "restore-test-2", version: 2)

      post restore_observ_prompt_version_path("restore-test-2", archived)

      expect(production.reload.state).to eq("archived")
      expect(archived.reload.state).to eq("production")
    end

    it "prevents restoring non-archived prompts" do
      draft = create(:observ_prompt, :draft, name: "restore-test-3")

      post restore_observ_prompt_version_path("restore-test-3", draft)

      expect(response).to redirect_to(observ_prompt_path("restore-test-3", version: draft.version))
      follow_redirect!
      expect(response.body).to include("Only archived prompts can be restored")
      expect(draft.reload.state).to eq("draft")
    end

    it "supports JSON response" do
      archived = create(:observ_prompt, :archived, name: "restore-test-4")

      post restore_observ_prompt_version_path("restore-test-4", archived), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end
  end

  describe "POST /observ/prompts/:prompt_id/versions/:id/clone" do
    it "creates draft copy of prompt" do
      production = create(:observ_prompt, :production, name: "clone-test-1", prompt: "Original content", version: 1)

      expect {
        post clone_observ_prompt_version_path("clone-test-1", production)
      }.to change(Observ::Prompt, :count).by(1)

      new_draft = Observ::Prompt.where(name: "clone-test-1").draft.first
      expect(new_draft.prompt).to eq("Original content")
      expect(new_draft.version).to eq(2)
      expect(response).to redirect_to(edit_observ_prompt_path("clone-test-1", version: new_draft.version))
    end

    it "copies configuration" do
      # Create production prompt with custom config
      production = create(:observ_prompt, :production, name: "clone-test-2",
                         prompt: "Test", version: 1,
                         config: { model: "gpt-4o", temperature: 0.8 })

      post clone_observ_prompt_version_path("clone-test-2", production)

      new_draft = Observ::Prompt.where(name: "clone-test-2").draft.first
      expect(new_draft.config["model"]).to eq("gpt-4o")
      expect(new_draft.config["temperature"]).to eq(0.8)
    end

    it "sets clone commit message" do
      production = create(:observ_prompt, :production, name: "clone-test-3", prompt: "Test", version: 1)

      post clone_observ_prompt_version_path("clone-test-3", production)

      new_draft = Observ::Prompt.where(name: "clone-test-3").draft.first
      expect(new_draft.commit_message).to include("Cloned from version 1")
    end

    it "works with archived prompts" do
      archived = create(:observ_prompt, :archived, name: "clone-test-4", prompt: "Archived content")

      expect {
        post clone_observ_prompt_version_path("clone-test-4", archived)
      }.to change(Observ::Prompt, :count).by(1)

      new_draft = Observ::Prompt.where(name: "clone-test-4").draft.first
      expect(new_draft.prompt).to eq("Archived content")
    end
  end
end
