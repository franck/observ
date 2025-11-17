# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::AssetSyncer do
  let(:gem_root) { Observ::Engine.root }
  let(:app_root) { Rails.root }
  let(:logger) { StringIO.new }
  let(:syncer) { described_class.new(gem_root: gem_root, app_root: app_root, logger: logger) }

  describe "#initialize" do
    it "accepts gem_root, app_root, and logger" do
      expect(syncer.gem_root).to eq(Pathname.new(gem_root))
      expect(syncer.app_root).to eq(Pathname.new(app_root))
      expect(syncer.logger).to eq(logger)
    end

    it "converts string paths to Pathnames" do
      syncer = described_class.new(
        gem_root: gem_root.to_s,
        app_root: app_root.to_s,
        logger: logger
      )
      expect(syncer.gem_root).to be_a(Pathname)
      expect(syncer.app_root).to be_a(Pathname)
    end
  end

  describe "#sync_stylesheets" do
    let(:dest_path) { Dir.mktmpdir }

    after { FileUtils.remove_entry(dest_path) }

    it "copies stylesheet files to destination" do
      result = syncer.sync_stylesheets(dest_path)

      expect(result[:files_copied]).to be > 0
      expect(File.exist?(File.join(dest_path, "_variables.scss"))).to be true
      expect(File.exist?(File.join(dest_path, "application.scss"))).to be true
    end

    it "creates destination directory if it doesn't exist" do
      nested_path = File.join(dest_path, "nested", "path")
      syncer.sync_stylesheets(nested_path)

      expect(Dir.exist?(nested_path)).to be true
    end

    it "skips files that haven't changed" do
      # First sync
      first_result = syncer.sync_stylesheets(dest_path)

      # Second sync without changes
      second_result = syncer.sync_stylesheets(dest_path)

      expect(second_result[:files_skipped]).to eq(first_result[:files_copied])
      expect(second_result[:files_copied]).to eq(0)
    end

    it "copies files that have changed" do
      # First sync
      syncer.sync_stylesheets(dest_path)

      # Modify a file
      modified_file = File.join(dest_path, "_variables.scss")
      File.write(modified_file, "// Modified content\n")

      # Second sync
      result = syncer.sync_stylesheets(dest_path)

      expect(result[:files_copied]).to eq(1)
      expect(File.read(modified_file)).not_to include("Modified content")
    end

    it "returns error if source directory doesn't exist" do
      invalid_syncer = described_class.new(
        gem_root: "/nonexistent",
        app_root: app_root,
        logger: logger
      )

      result = invalid_syncer.sync_stylesheets(dest_path)

      expect(result[:error]).to eq("Source directory not found")
      expect(result[:files_copied]).to eq(0)
    end

    it "logs progress messages" do
      syncer.sync_stylesheets(dest_path)
      output = logger.string

      expect(output).to include("Syncing Observ stylesheets")
      expect(output).to include("✓ Copied")
      expect(output).to include("Total:")
    end
  end

  describe "#sync_javascript_controllers" do
    let(:dest_path) { Dir.mktmpdir }

    after { FileUtils.remove_entry(dest_path) }

    it "copies JavaScript controller files to destination" do
      result = syncer.sync_javascript_controllers(dest_path)

      expect(result[:files_copied]).to be > 0
      expect(File.exist?(File.join(dest_path, "autoscroll_controller.js"))).to be true
      expect(File.exist?(File.join(dest_path, "drawer_controller.js"))).to be true
    end

    it "creates destination directory if it doesn't exist" do
      nested_path = File.join(dest_path, "nested", "path")
      syncer.sync_javascript_controllers(nested_path)

      expect(Dir.exist?(nested_path)).to be true
    end

    it "skips files that haven't changed" do
      # First sync
      first_result = syncer.sync_javascript_controllers(dest_path)

      # Second sync without changes
      second_result = syncer.sync_javascript_controllers(dest_path)

      expect(second_result[:files_skipped]).to eq(first_result[:files_copied])
      expect(second_result[:files_copied]).to eq(0)
    end

    it "logs progress messages" do
      syncer.sync_javascript_controllers(dest_path)
      output = logger.string

      expect(output).to include("Syncing Observ JavaScript controllers")
      expect(output).to include("✓ Copied")
      expect(output).to include("Total:")
    end
  end
end
