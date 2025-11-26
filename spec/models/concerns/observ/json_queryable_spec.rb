# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::JsonQueryable do
  # Test with Session as the concrete class
  describe ".where_json" do
    let!(:agent_a_session) { create(:observ_session, metadata: { "agent_type" => "AgentA", "version" => "1.0" }) }
    let!(:agent_b_session) { create(:observ_session, metadata: { "agent_type" => "AgentB", "version" => "2.0" }) }
    let!(:no_agent_session) { create(:observ_session, metadata: { "version" => "1.0" }) }
    let!(:nil_metadata_session) { create(:observ_session, metadata: nil) }

    it "filters by JSON field value" do
      results = Observ::Session.where_json(:metadata, :agent_type, "AgentA")
      expect(results).to contain_exactly(agent_a_session)
    end

    it "returns empty when no match" do
      results = Observ::Session.where_json(:metadata, :agent_type, "NonExistent")
      expect(results).to be_empty
    end

    it "can be chained with other scopes" do
      results = Observ::Session
        .where_json(:metadata, :agent_type, "AgentA")
        .where_json(:metadata, :version, "1.0")
      expect(results).to contain_exactly(agent_a_session)
    end

    it "handles string paths" do
      results = Observ::Session.where_json(:metadata, "agent_type", "AgentB")
      expect(results).to contain_exactly(agent_b_session)
    end
  end

  describe ".where_json_present" do
    let!(:with_agent) { create(:observ_session, metadata: { "agent_type" => "Agent" }) }
    let!(:without_agent) { create(:observ_session, metadata: { "other" => "value" }) }
    let!(:nil_metadata) { create(:observ_session, metadata: nil) }

    it "filters records where JSON field is present" do
      results = Observ::Session.where_json_present(:metadata, :agent_type)
      expect(results).to contain_exactly(with_agent)
    end
  end

  describe ".pluck_json" do
    let!(:session1) { create(:observ_session, metadata: { "agent_type" => "AgentA" }) }
    let!(:session2) { create(:observ_session, metadata: { "agent_type" => "AgentB" }) }
    let!(:session3) { create(:observ_session, metadata: { "other" => "value" }) }

    it "plucks JSON field values" do
      results = Observ::Session.where.not(metadata: nil).pluck_json(:metadata, :agent_type)
      expect(results).to include("AgentA", "AgentB")
    end
  end

  describe "nested paths" do
    let!(:nested_session) do
      create(:observ_session, metadata: {
        "config" => {
          "mode" => "production",
          "settings" => { "debug" => false }
        }
      })
    end

    it "queries nested JSON paths" do
      results = Observ::Session.where_json(:metadata, "config.mode", "production")
      expect(results).to contain_exactly(nested_session)
    end
  end

  describe "inclusion in models" do
    it "is included in Session" do
      expect(Observ::Session).to respond_to(:where_json)
      expect(Observ::Session).to respond_to(:where_json_present)
      expect(Observ::Session).to respond_to(:pluck_json)
    end
  end
end
