# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::IndexFileGenerator do
  let(:app_root) { Dir.mktmpdir }
  let(:logger) { StringIO.new }
  let(:generator) { described_class.new(app_root: app_root, logger: logger) }

  after { FileUtils.remove_entry(app_root) }

  describe "#initialize" do
    it "accepts app_root and logger" do
      expect(generator.app_root).to eq(Pathname.new(app_root))
      expect(generator.logger).to eq(logger)
    end

    it "converts string paths to Pathnames" do
      generator = described_class.new(app_root: app_root.to_s, logger: logger)
      expect(generator.app_root).to be_a(Pathname)
    end
  end

  describe "#generate_controllers_index" do
    let(:controllers_path) { File.join(app_root, "app", "javascript", "controllers", "observ") }

    before do
      FileUtils.mkdir_p(controllers_path)
    end

    context "with controller files present" do
      before do
        # Create sample controller files
        File.write(File.join(controllers_path, "autoscroll_controller.js"), "// Autoscroll controller")
        File.write(File.join(controllers_path, "drawer_controller.js"), "// Drawer controller")
        File.write(File.join(controllers_path, "copy_controller.js"), "// Copy controller")
      end

      it "generates an index file with imports and registrations" do
        result = generator.generate_controllers_index(controllers_path)
        index_file = File.join(controllers_path, "index.js")

        expect(result[:created]).to be true
        expect(File.exist?(index_file)).to be true

        content = File.read(index_file)
        expect(content).to include("import AutoscrollController from \"./autoscroll_controller.js\"")
        expect(content).to include("import DrawerController from \"./drawer_controller.js\"")
        expect(content).to include("import CopyController from \"./copy_controller.js\"")
        expect(content).to include("application.register(\"observ--autoscroll\", AutoscrollController)")
        expect(content).to include("application.register(\"observ--drawer\", DrawerController)")
        expect(content).to include("application.register(\"observ--copy\", CopyController)")
      end

      it "includes the application import" do
        generator.generate_controllers_index(controllers_path)
        index_file = File.join(controllers_path, "index.js")
        content = File.read(index_file)

        expect(content).to include("import { application } from \"../application\"")
      end

      it "does not update if content hasn't changed" do
        # First generation
        result1 = generator.generate_controllers_index(controllers_path)
        expect(result1[:created]).to be true

        # Second generation
        result2 = generator.generate_controllers_index(controllers_path)
        expect(result2[:created]).to be false
        expect(result2[:updated]).to be false
      end

      it "updates if content has changed" do
        # First generation
        generator.generate_controllers_index(controllers_path)

        # Add a new controller
        File.write(File.join(controllers_path, "new_controller.js"), "// New controller")

        # Second generation
        result = generator.generate_controllers_index(controllers_path)
        expect(result[:updated]).to be true

        content = File.read(File.join(controllers_path, "index.js"))
        expect(content).to include("NewController")
      end

      it "logs creation message" do
        generator.generate_controllers_index(controllers_path)
        output = logger.string

        expect(output).to include("✓ Created index file")
      end

      it "logs update message when updating" do
        # Create initial index
        generator.generate_controllers_index(controllers_path)
        logger.string = ""

        # Modify index manually
        index_file = File.join(controllers_path, "index.js")
        File.write(index_file, "// Modified")

        # Regenerate
        generator.generate_controllers_index(controllers_path)
        output = logger.string

        expect(output).to include("✓ Updated index file")
      end
    end

    context "with no controller files" do
      it "returns an error" do
        result = generator.generate_controllers_index(controllers_path)

        expect(result[:created]).to be false
        expect(result[:error]).to eq("No controller files found")
      end

      it "logs a warning" do
        generator.generate_controllers_index(controllers_path)
        output = logger.string

        expect(output).to include("⚠ No controller files found")
      end
    end
  end

  describe "#check_main_controllers_registration" do
    let(:main_index_path) { File.join(app_root, "app", "javascript", "controllers") }
    let(:main_index_file) { File.join(main_index_path, "index.js") }

    context "when main index file doesn't exist" do
      it "returns not registered with suggestions" do
        result = generator.check_main_controllers_registration

        expect(result[:registered]).to be false
        expect(result[:main_index_exists]).to be false
        expect(result[:suggestions]).to be_present
        expect(result[:suggestions].first).to include("not found")
      end
    end

    context "when main index file exists but observ not registered" do
      before do
        FileUtils.mkdir_p(main_index_path)
        File.write(main_index_file, "import { application } from './application'\n")
      end

      it "returns not registered with import suggestions" do
        result = generator.check_main_controllers_registration

        expect(result[:registered]).to be false
        expect(result[:main_index_exists]).to be true
        expect(result[:suggestions]).to be_present
        expect(result[:suggestions].join("\n")).to include("import './observ'")
      end
    end

    context "when observ is already registered" do
      before do
        FileUtils.mkdir_p(main_index_path)
        File.write(main_index_file, <<~JS)
          import { application } from './application'
          import './observ'
        JS
      end

      it "returns registered" do
        result = generator.check_main_controllers_registration

        expect(result[:registered]).to be true
        expect(result[:main_index_exists]).to be true
        expect(result[:suggestions]).to be_nil
      end
    end
  end

  describe "#generate_import_statement" do
    it "generates default import statement" do
      statement = generator.generate_import_statement

      expect(statement).to eq("\nimport './observ'\n")
    end

    it "generates custom import statement" do
      statement = generator.generate_import_statement("./custom/path")

      expect(statement).to eq("\nimport './custom/path'\n")
    end
  end
end
