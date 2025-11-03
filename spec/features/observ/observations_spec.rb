require 'rails_helper'

RSpec.feature "Observ Observations", type: :feature do
  let!(:session1) { create(:observ_session) }
  let!(:trace1) { create(:observ_trace, observ_session: session1) }
  let!(:trace2) { create(:observ_trace, observ_session: session1) }
  let!(:generation1) { create(:observ_generation, trace: trace1, name: "Chat Completion", model: "gpt-4", start_time: 1.hour.ago, usage: { "total_tokens" => 500 }, cost_usd: 0.03) }
  let!(:generation2) { create(:observ_generation, trace: trace2, name: "Embedding", model: "text-embedding-ada", start_time: 2.hours.ago, usage: { "total_tokens" => 1000 }, cost_usd: 0.01) }
  let!(:span1) { create(:observ_span, trace: trace1, name: "Database Query", start_time: 3.hours.ago) }

  scenario "User views observations list" do
    visit observ_observations_path

    expect(page).to have_content("Observations")
    expect(page).to have_content(generation1.observation_id[0..11])
    expect(page).to have_content(generation2.observation_id[0..11])
    expect(page).to have_content(span1.observation_id[0..11])
  end

  scenario "User sees observation types" do
    visit observ_observations_path

    within("table.observ-table") do
      expect(page).to have_content("Generation")
      expect(page).to have_content("Span")
    end
  end

  scenario "User sees observation details in table" do
    visit observ_observations_path

    within("tr", text: generation1.observation_id[0..11]) do
      expect(page).to have_content("Chat Completion")
      expect(page).to have_content("Generation")
      expect(page).to have_content(trace1.trace_id[0..7])
    end
  end

  scenario "User clicks on an observation to view details" do
    visit observ_observations_path

    within("tr", text: generation1.observation_id[0..11]) do
      click_link "View"
    end

    expect(page).to have_current_path(observ_observation_path(generation1))
    expect(page).to have_content(generation1.observation_id[0..11])
  end

  scenario "User views generation detail page" do
    visit observ_observation_path(generation1)

    expect(page).to have_content(generation1.observation_id[0..11])
    expect(page).to have_content("gpt-4")
    expect(page).to have_content("500")
    expect(page).to have_content("$0.03")
  end

  scenario "User views span detail page" do
    visit observ_observation_path(span1)

    expect(page).to have_content(span1.observation_id[0..11])
    expect(page).to have_content("Database Query")
  end

  scenario "User filters observations to show only generations" do
    visit observ_observations_path

    click_link "Generations"

    expect(page).to have_current_path(generations_observ_observations_path)
    expect(page).to have_content(generation1.observation_id[0..11])
    expect(page).to have_content(generation2.observation_id[0..11])
    expect(page).not_to have_content(span1.observation_id[0..11])
  end

  scenario "User filters observations to show only spans" do
    visit observ_observations_path

    click_link "Spans"

    expect(page).to have_current_path(spans_observ_observations_path)
    expect(page).to have_content(span1.observation_id[0..11])
    expect(page).not_to have_content(generation1.observation_id[0..11])
  end

  scenario "User sees token counts for generations" do
    visit observ_observations_path

    within("tr", text: generation1.observation_id[0..11]) do
      expect(page).to have_content("500")
    end

    within("tr", text: span1.observation_id[0..11]) do
      expect(page).to have_content("—")
    end
  end

  scenario "User sees cost for generations" do
    visit observ_observations_path

    within("tr", text: generation1.observation_id[0..11]) do
      expect(page).to have_content("$0.03")
    end

    within("tr", text: span1.observation_id[0..11]) do
      expect(page).to have_content("—")
    end
  end

  scenario "User can filter to show only generations" do
    visit observ_observations_path

    click_link "Generations"

    expect(page).to have_current_path(generations_observ_observations_path)
    expect(page).to have_content(generation1.observation_id[0..11])
  end

  scenario "User can filter to show only spans" do
    visit observ_observations_path

    click_link "Spans"

    expect(page).to have_current_path(spans_observ_observations_path)
    expect(page).to have_content(span1.observation_id[0..11])
  end

  scenario "User navigates through paginated observations" do
    create_list(:observ_generation, 30, trace: trace1)

    visit observ_observations_path

    expect(page).to have_css("tbody tr.observ-table__row", minimum: 24)

    if page.has_link?("Next")
      click_link "Next"
      expect(page).to have_css(".observ-table__row")
    end
  end

  scenario "User sees empty state when no observations" do
    Observ::Observation.destroy_all

    visit observ_observations_path

    expect(page).to have_content("No observations found")
  end

  scenario "User clicks on trace link from observation" do
    visit observ_observations_path

    first("a", text: trace1.trace_id[0..7]).click

    expect(page).to have_current_path(observ_trace_path(trace1))
  end

  scenario "User sees observation duration" do
    visit observ_observations_path

    if generation1.duration_ms.present?
      expect(page).to have_content(/\d+ms/)
    else
      expect(page).to have_content("—")
    end
  end

  scenario "User sees badges for observation types" do
    visit observ_observations_path

    expect(page).to have_css(".observ-badge--generation")
    expect(page).to have_css(".observ-badge--span")
  end
end
