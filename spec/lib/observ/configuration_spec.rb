# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values for prompt management" do
      expect(config.prompt_management_enabled).to be true
      expect(config.prompt_cache_ttl).to eq(300)
      expect(config.prompt_fallback_behavior).to eq(:raise)
      expect(config.prompt_cache_store).to eq(:redis_cache_store)
      expect(config.prompt_cache_prefix).to eq("observ:prompt")
      expect(config.prompt_cache_namespace).to eq("observ:prompt")
      expect(config.prompt_max_versions).to eq(100)
      expect(config.prompt_default_state).to eq(:production)
      expect(config.prompt_allow_production_deletion).to be false
      expect(config.prompt_cache_warming_enabled).to be true
      expect(config.prompt_cache_critical_prompts).to eq([])
      expect(config.prompt_cache_monitoring_enabled).to be true
      expect(config.prompt_config_schema_strict).to be false
    end

    it "sets default back_to_app_path as a lambda returning root path" do
      expect(config.back_to_app_path).to be_a(Proc)
      expect(config.back_to_app_path.call).to eq("/")
    end

    it "sets default chat_ui_enabled as a lambda" do
      expect(config.chat_ui_enabled).to be_a(Proc)
    end

    it "sets agent_path to nil by default" do
      expect(config.agent_path).to be_nil
    end

    it "sets pagination_per_page to 25 by default" do
      expect(config.pagination_per_page).to eq(25)
    end

    it "sets default prompt_config_schema" do
      schema = config.prompt_config_schema
      expect(schema).to be_a(Hash)
      expect(schema).to have_key(:temperature)
      expect(schema).to have_key(:max_tokens)
      expect(schema).to have_key(:model)
    end
  end

  describe "#back_to_app_path" do
    it "can be configured with a custom path" do
      config.back_to_app_path = -> { "/custom/path" }
      expect(config.back_to_app_path.call).to eq("/custom/path")
    end

    it "accepts a lambda that can reference external helpers" do
      custom_path = "/dashboard"
      config.back_to_app_path = -> { custom_path }
      expect(config.back_to_app_path.call).to eq("/dashboard")
    end
  end

  describe "#chat_ui_enabled?" do
    it "returns the result of calling the lambda when chat_ui_enabled is a proc" do
      config.chat_ui_enabled = -> { true }
      expect(config.chat_ui_enabled?).to be true

      config.chat_ui_enabled = -> { false }
      expect(config.chat_ui_enabled?).to be false
    end

    it "returns the boolean value when chat_ui_enabled is not a proc" do
      config.chat_ui_enabled = true
      expect(config.chat_ui_enabled?).to be true

      config.chat_ui_enabled = false
      expect(config.chat_ui_enabled?).to be false
    end
  end

  describe "#default_prompt_config_schema" do
    let(:schema) { config.default_prompt_config_schema }

    it "defines temperature with float type and range" do
      expect(schema[:temperature]).to eq(
        type: :float,
        required: false,
        range: 0.0..2.0,
        default: 0.7
      )
    end

    it "defines max_tokens with integer type and range" do
      expect(schema[:max_tokens]).to eq(
        type: :integer,
        required: false,
        range: 1..100000
      )
    end

    it "defines top_p with float type and range" do
      expect(schema[:top_p]).to eq(
        type: :float,
        required: false,
        range: 0.0..1.0
      )
    end

    it "defines frequency_penalty with float type and range" do
      expect(schema[:frequency_penalty]).to eq(
        type: :float,
        required: false,
        range: -2.0..2.0
      )
    end

    it "defines presence_penalty with float type and range" do
      expect(schema[:presence_penalty]).to eq(
        type: :float,
        required: false,
        range: -2.0..2.0
      )
    end

    it "defines stop_sequences as array of strings" do
      expect(schema[:stop_sequences]).to eq(
        type: :array,
        required: false,
        item_type: :string
      )
    end

    it "defines model as string type" do
      expect(schema[:model]).to eq(
        type: :string,
        required: false
      )
    end

    it "defines response_format as hash type" do
      expect(schema[:response_format]).to eq(
        type: :hash,
        required: false
      )
    end

    it "defines seed as integer type" do
      expect(schema[:seed]).to eq(
        type: :integer,
        required: false
      )
    end

    it "defines stream as boolean type" do
      expect(schema[:stream]).to eq(
        type: :boolean,
        required: false
      )
    end
  end

  describe "Observ.configure" do
    after do
      # Reset to defaults after each test
      Observ.instance_variable_set(:@configuration, nil)
    end

    it "yields the configuration" do
      Observ.configure do |c|
        expect(c).to be_a(Observ::Configuration)
      end
    end

    it "allows setting configuration options" do
      Observ.configure do |c|
        c.back_to_app_path = -> { "/my-app" }
        c.pagination_per_page = 50
      end

      expect(Observ.config.back_to_app_path.call).to eq("/my-app")
      expect(Observ.config.pagination_per_page).to eq(50)
    end
  end
end
