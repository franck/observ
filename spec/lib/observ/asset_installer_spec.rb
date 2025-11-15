# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::AssetInstaller do
  let(:gem_root) { Observ::Engine.root }
  let(:app_root) { Dir.mktmpdir }
  let(:logger) { StringIO.new }
  let(:installer) { described_class.new(gem_root: gem_root, app_root: app_root, logger: logger) }

  after { FileUtils.remove_entry(app_root) }

  describe "#initialize" do
    it "accepts gem_root, app_root, and logger" do
      expect(installer.gem_root).to eq(Pathname.new(gem_root))
      expect(installer.app_root).to eq(Pathname.new(app_root))
      expect(installer.logger).to eq(logger)
    end
  end

  describe "#install" do
    it "installs stylesheets and JavaScript controllers to default locations" do
      result = installer.install

      expect(result[:styles][:files_copied]).to be > 0
      expect(result[:javascript][:files_copied]).to be > 0
      expect(result[:paths][:styles].to_s).to include("app/javascript/stylesheets/observ")
      expect(result[:paths][:javascript].to_s).to include("app/javascript/controllers/observ")
    end

    it "installs to custom destinations" do
      result = installer.install(
        styles_dest: "custom/styles",
        js_dest: "custom/controllers"
      )

      expect(result[:paths][:styles].to_s).to include("custom/styles")
      expect(result[:paths][:javascript].to_s).to include("custom/controllers")
    end

    it "generates index files by default" do
      result = installer.install

      expect(result[:index]).to be_present
      expect(result[:index][:created]).to be true
      expect(result[:registration]).to be_present
    end

    it "skips index generation when requested" do
      result = installer.install(generate_index: false)

      expect(result[:index]).to be_nil
      expect(result[:registration]).to be_nil
    end

    it "checks controller registration" do
      result = installer.install

      expect(result[:registration]).to be_present
      expect(result[:registration]).to have_key(:registered)
      expect(result[:registration]).to have_key(:main_index_exists)
    end

    it "logs installation header" do
      installer.install
      output = logger.string

      expect(output).to include("Observ Asset Installation")
      expect(output).to include("Gem location:")
      expect(output).to include("App location:")
    end

    it "logs installation footer" do
      installer.install
      output = logger.string

      expect(output).to include("✓ Asset installation complete!")
      expect(output).to include("Next steps:")
    end

    it "returns paths used for installation" do
      result = installer.install(
        styles_dest: "custom/styles",
        js_dest: "custom/js"
      )

      expect(result[:paths][:styles]).to eq(Pathname.new(app_root).join("custom/styles"))
      expect(result[:paths][:javascript]).to eq(Pathname.new(app_root).join("custom/js"))
    end
  end

  describe "#sync" do
    it "syncs assets without generating index files" do
      result = installer.sync

      expect(result[:styles][:files_copied]).to be > 0
      expect(result[:javascript][:files_copied]).to be > 0
      expect(result[:index]).to be_nil
      expect(result[:registration]).to be_nil
    end

    it "accepts custom destinations" do
      result = installer.sync(
        styles_dest: "sync/styles",
        js_dest: "sync/controllers"
      )

      expect(result[:paths][:styles].to_s).to include("sync/styles")
      expect(result[:paths][:javascript].to_s).to include("sync/controllers")
    end
  end

  describe "DEFAULT_STYLES_DEST" do
    it "is set to app/javascript/stylesheets/observ" do
      expect(described_class::DEFAULT_STYLES_DEST).to eq("app/javascript/stylesheets/observ")
    end
  end

  describe "DEFAULT_JS_DEST" do
    it "is set to app/javascript/controllers/observ" do
      expect(described_class::DEFAULT_JS_DEST).to eq("app/javascript/controllers/observ")
    end
  end
end
