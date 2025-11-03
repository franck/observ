require 'rails_helper'

RSpec.feature "Observ Traces", type: :feature do
  let!(:session1) { create(:observ_session) }
  let!(:session2) { create(:observ_session) }
  let!(:trace1) { create(:observ_trace, observ_session: session1, name: "Chat Request", start_time: 1.hour.ago) }
  let!(:trace2) { create(:observ_trace, observ_session: session2, name: "Background Job", start_time: 2.hours.ago) }
  let!(:generation1) { create(:observ_generation, trace: trace1, model: "gpt-4", cost_usd: 0.03) }
  let!(:span1) { create(:observ_span, trace: trace1, name: "Database Query") }

  scenario "User views traces list" do
    visit observ_traces_path

    expect(page).to have_content("Traces")
    expect(page).to have_content(trace1.trace_id[0..11])
    expect(page).to have_content(trace2.trace_id[0..11])
  end

  scenario "User sees trace details in table" do
    visit observ_traces_path

    within("table.observ-table") do
      expect(page).to have_content("Chat Request")
      expect(page).to have_content("Background Job")
      expect(page).to have_content(session1.session_id[0..7])
    end
  end

  scenario "User clicks on a trace to view details" do
    visit observ_traces_path

    within("tr", text: trace1.trace_id[0..11]) do
      click_link "View"
    end

    expect(page).to have_current_path(observ_trace_path(trace1))
    expect(page).to have_content(trace1.trace_id[0..11])
  end

  scenario "User views trace detail page" do
    visit observ_trace_path(trace1)

    expect(page).to have_content(trace1.trace_id[0..11])
    expect(page).to have_content("Chat Request")
    expect(page).to have_content("Observations")
  end

  scenario "User sees observations within a trace" do
    visit observ_trace_path(trace1)

    expect(page).to have_content(generation1.observation_id[0..7])
    expect(page).to have_content(span1.observation_id[0..7])
  end

  scenario "User sees generation and span labels" do
    visit observ_trace_path(trace1)

    expect(page).to have_content("Generation")
    expect(page).to have_content("Span")
  end

  scenario "User can access trace details" do
    visit observ_traces_path

    expect(page).to have_content(trace1.trace_id[0..11])
    expect(page).to have_content(trace2.trace_id[0..11])
  end

  scenario "User navigates through paginated traces" do
    create_list(:observ_trace, 30, observ_session: session1)

    visit observ_traces_path

    expect(page).to have_css("tbody tr.observ-table__row", minimum: 24)

    if page.has_link?("Next")
      click_link "Next"
      expect(page).to have_css(".observ-table__row")
    end
  end

  scenario "User sees empty state when no traces" do
    Observ::Trace.destroy_all

    visit observ_traces_path

    expect(page).to have_content("No traces found")
  end

  scenario "User clicks on session link from trace" do
    visit observ_traces_path

    click_link session1.session_id[0..7]

    expect(page).to have_current_path(observ_session_path(session1))
  end

  scenario "User sees trace duration" do
    visit observ_traces_path

    if trace1.duration_ms.present?
      expect(page).to have_content(/\d+ms/)
    else
      expect(page).to have_content("In Progress")
    end
  end

  scenario "User sees trace cost and tokens" do
    visit observ_traces_path

    within("tr", text: trace1.trace_id[0..11]) do
      expect(page).to have_css(".observ-table__cell--numeric")
    end
  end
end
