require "rails_helper"

RSpec.describe "Prompt Management", type: :feature do
  scenario "User creates a new prompt" do
    visit observ_prompts_path
    click_link "New Prompt"

    fill_in "Prompt Name", with: "test-agent-prompt"
    fill_in "Commit Message", with: "Initial version"
    fill_in "Prompt Content", with: "Hello {{name}}, you are {{role}}"

    # Fill in config using the new structured fields
    fill_in "Temperature", with: "0.7"

    click_button "Create Prompt"

    expect(page).to have_content("Prompt created successfully")
    expect(page).to have_content("test-agent-prompt")
    expect(page).to have_content("Hello {{name}}, you are {{role}}")
  end

  scenario "User creates and immediately promotes to production" do
    visit new_observ_prompt_path

    fill_in "Prompt Name", with: "production-prompt"
    fill_in "Prompt Content", with: "System prompt content"
    check "Promote to production immediately"

    click_button "Create Prompt"

    expect(page).to have_content("Prompt created successfully")
    expect(page).to have_content("Production")
    expect(page).to have_content("Currently in Use")
  end

  scenario "User edits a draft prompt" do
    draft = create(:observ_prompt, :draft, name: "my-prompt", prompt: "Original content")

    visit observ_prompt_path("my-prompt", version: draft.version)
    click_link "Edit"

    fill_in "Prompt Content", with: "Updated content"
    fill_in "Commit Message", with: "Updated prompt text"
    click_button "Update Draft"

    expect(page).to have_content("Prompt updated successfully")
    expect(page).to have_content("Updated content")
  end

  scenario "User promotes draft to production" do
    draft = create(:observ_prompt, :draft, name: "my-prompt")

    visit observ_prompt_path("my-prompt", version: draft.version)

    click_button "Promote to Production"

    expect(page).to have_content("promoted to production")
    expect(page).to have_content("Production")
  end

  scenario "User promotes new version, demoting old production" do
    production = create(:observ_prompt, :production, name: "my-prompt", version: 1)
    draft = create(:observ_prompt, :draft, name: "my-prompt", version: 2)

    visit observ_prompt_path("my-prompt", version: draft.version)
    click_button "Promote to Production"

    expect(page).to have_content("promoted to production")

    # Check that old version was demoted
    production.reload
    expect(production.state).to eq("archived")
  end

  scenario "User clones a production prompt to draft" do
    production = create(:observ_prompt, :production, name: "my-prompt", prompt: "Production content")

    visit observ_prompt_path("my-prompt", version: production.version)
    click_button "Clone to Draft"

    expect(page).to have_content("Created editable draft")
    expect(page).to have_content("Edit Prompt Draft")
    expect(page).to have_content("Production content")
  end

  scenario "User compares two versions" do
    v1 = create(:observ_prompt, :production, name: "my-prompt", version: 1, prompt: "Version 1 content")
    v2 = create(:observ_prompt, :draft, name: "my-prompt", version: 2, prompt: "Version 2 content")

    visit observ_prompt_path("my-prompt")
    click_link "Compare Versions"

    select "v1 (production)", from: "From Version"
    select "v2 (draft)", from: "To Version"
    click_button "Compare"

    expect(page).to have_content("Version 1")
    expect(page).to have_content("Version 2")
    expect(page).to have_content("Version 1 content")
    expect(page).to have_content("Version 2 content")
  end

  scenario "User views version history" do
    create(:observ_prompt, :production, name: "my-prompt", version: 1, commit_message: "Initial version")
    create(:observ_prompt, :archived, name: "my-prompt", version: 2, commit_message: "Second version")
    create(:observ_prompt, :draft, name: "my-prompt", version: 3, commit_message: "Draft changes")

    visit observ_prompt_path("my-prompt")
    click_link "View History"

    expect(page).to have_content("Version History")
    expect(page).to have_content("Version 1")
    expect(page).to have_content("Version 2")
    expect(page).to have_content("Version 3")
    expect(page).to have_content("Initial version")
    expect(page).to have_content("Second version")
    expect(page).to have_content("Draft changes")
  end

  scenario "User searches for prompts" do
    create(:observ_prompt, :production, name: "research-agent-prompt")
    create(:observ_prompt, :production, name: "chat-agent-prompt")
    create(:observ_prompt, :production, name: "summary-tool-prompt")

    visit observ_prompts_path

    fill_in "Search prompts", with: "agent"
    click_button "Filter"

    expect(page).to have_content("research-agent-prompt")
    expect(page).to have_content("chat-agent-prompt")
    expect(page).not_to have_content("summary-tool-prompt")
  end

  scenario "User filters prompts by state" do
    create(:observ_prompt, :draft, name: "draft-prompt")
    create(:observ_prompt, :production, name: "prod-prompt")
    create(:observ_prompt, :archived, name: "archived-prompt")

    visit observ_prompts_path

    select "Draft", from: "Filter by state"
    click_button "Filter"

    expect(page).to have_content("draft-prompt")
    expect(page).not_to have_content("prod-prompt")
    expect(page).not_to have_content("archived-prompt")
  end

  scenario "User deletes a draft prompt" do
    draft = create(:observ_prompt, :draft, name: "temp-prompt")

    visit observ_prompt_path("temp-prompt", version: draft.version)

    click_button "Delete"

    expect(page).to have_content("Prompt version")
    expect(page).to have_content("deleted")
    expect(Observ::Prompt.find_by(id: draft.id)).to be_nil
  end

  scenario "User cannot edit production prompt directly" do
    production = create(:observ_prompt, :production, name: "prod-prompt")

    visit edit_observ_prompt_path("prod-prompt", version: production.version)

    expect(page).to have_content("Only draft prompts can be edited")
    expect(page).not_to have_content("Edit Prompt Draft")
  end

  scenario "User cannot delete production prompt" do
    production = create(:observ_prompt, :production, name: "prod-prompt")

    visit observ_prompt_path("prod-prompt", version: production.version)

    # Production prompts should not have a delete button
    expect(page).not_to have_button("Delete")
  end

  scenario "User restores archived prompt to production" do
    archived = create(:observ_prompt, :archived, name: "old-prompt")

    visit observ_prompt_path("old-prompt", version: archived.version)

    click_button "Restore to Production"

    expect(page).to have_content("restored to production")
    expect(page).to have_content("Production")
  end
end
