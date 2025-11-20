require 'rails_helper'

RSpec.feature "Observ Sessions", type: :feature do
  let!(:session1) { create(:observ_session, user_id: "user-123", start_time: 1.hour.ago, total_tokens: 1500, total_cost: 0.05) }
  let!(:session2) { create(:observ_session, user_id: "user-456", start_time: 2.hours.ago, total_tokens: 3000, total_cost: 0.15) }
  let!(:trace1) do
    create(:observ_trace, observ_session: session1, name: "Chat Request",
           total_tokens: 1500, total_cost: 0.05)
  end
  let!(:trace2) do
    create(:observ_trace, observ_session: session2, name: "Background Job",
           total_tokens: 3000, total_cost: 0.15)
  end

  scenario "User views sessions list" do
    visit observ_sessions_path

    expect(page).to have_content("Sessions")
    expect(page).to have_content(session1.session_id[0..11])
    expect(page).to have_content(session2.session_id[0..11])
  end

  scenario "User sees session details in table" do
    visit observ_sessions_path

    within("table.observ-table") do
      expect(page).to have_content("user-123"[0..7])
      expect(page).to have_content("user-456"[0..7])
      expect(page).to have_content("1.5K")
      expect(page).to have_content("3.0K")
    end
  end

  scenario "User clicks on a session to view details" do
    visit observ_sessions_path

    within("tr", text: session1.session_id[0..11]) do
      click_link "View"
    end

    expect(page).to have_current_path(observ_session_path(session1))
    expect(page).to have_content(session1.session_id[0..11])
  end

  scenario "User views session detail page" do
    visit observ_session_path(session1)

    expect(page).to have_content(session1.session_id[0..11])
    expect(page).to have_content("Traces")
    expect(page).to have_content("1.5K")
  end

  scenario "User sees traces within a session" do
    visit observ_session_path(session1)

    expect(page).to have_content(trace1.trace_id[0..11])
    expect(page).to have_content("Chat Request")
  end

  scenario "User can access session details" do
    visit observ_sessions_path

    expect(page).to have_content(session1.session_id[0..11])
    expect(page).to have_content(session2.session_id[0..11])
  end

  scenario "User navigates through paginated sessions" do
    create_list(:observ_session, 30)

    visit observ_sessions_path

    expect(page).to have_css("tbody tr.observ-table__row", minimum: 24)

    if page.has_link?("Next")
      click_link "Next"
      expect(page).to have_css(".observ-table__row")
    end
  end

  scenario "User sees empty state when no sessions" do
    Observ::Session.destroy_all

    visit observ_sessions_path

    expect(page).to have_content("No sessions found")
  end

  scenario "User sees session status badge" do
    visit observ_sessions_path

    expect(page).to have_css(".observ-badge")
  end
end
