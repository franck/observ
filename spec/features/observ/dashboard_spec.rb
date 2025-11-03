require 'rails_helper'

RSpec.feature "Observ Dashboard", type: :feature do
  let!(:session1) { create(:observ_session, start_time: 1.hour.ago, total_tokens: 1500, total_cost: 0.05, total_llm_calls_count: 3) }
  let!(:session2) { create(:observ_session, start_time: 2.days.ago, total_tokens: 3000, total_cost: 0.15, total_llm_calls_count: 5) }
  let!(:trace1) { create(:observ_trace, observ_session: session1, name: "Chat Request") }
  let!(:trace2) { create(:observ_trace, observ_session: session2, name: "Background Job") }
  let!(:generation1) { create(:observ_generation, trace: trace1, model: "gpt-4", cost_usd: 0.03, usage: { "total_tokens" => 500 }) }
  let!(:generation2) { create(:observ_generation, trace: trace2, model: "gpt-3.5-turbo", cost_usd: 0.01, usage: { "total_tokens" => 800 }) }

  scenario "User views the dashboard homepage" do
    visit observ_root_path

    expect(page).to have_content("Total Sessions")
    expect(page).to have_content("Total Traces")
    expect(page).to have_content("LLM Calls")
    expect(page).to have_content("Total Tokens")
    expect(page).to have_content("Total Cost")
  end

  scenario "User sees metrics on dashboard" do
    visit observ_dashboard_path

    expect(page).to have_css(".observ-metric-card")
    expect(page).to have_content("Total Sessions")
    expect(page).to have_content("Total Traces")
  end

  scenario "User sees recent sessions" do
    visit observ_dashboard_path

    expect(page).to have_content(session1.session_id[0..11])
    expect(page).to have_content(session2.session_id[0..11])
  end

  scenario "User filters dashboard by time period" do
    visit observ_dashboard_path

    within(".observ-period-selector") do
      select "Last 24 Hours", from: "period"
    end

    expect(page).to have_content("Observability Dashboard")
  end

  scenario "User navigates from dashboard to sessions" do
    visit observ_dashboard_path

    click_link "View All"

    expect(page).to have_current_path(observ_sessions_path)
  end

  scenario "Dashboard displays cost breakdown by model" do
    visit observ_dashboard_path

    expect(page).to have_content("Cost by Model")
    expect(page).to have_content("gpt-4")
    expect(page).to have_content("gpt-3.5-turbo")
  end

  scenario "Dashboard shows all key metrics" do
    visit observ_dashboard_path

    expect(page).to have_content("Total Tokens")
    expect(page).to have_content("Avg Latency")
    expect(page).to have_content("Success Rate")
  end
end
