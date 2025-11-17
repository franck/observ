# frozen_string_literal: true

module Observ
  # Service class for generating index files for Stimulus controllers
  class IndexFileGenerator
    attr_reader :app_root, :logger

    # @param app_root [String, Pathname] Root directory of the host application
    # @param logger [Logger, IO] Logger for output (defaults to STDOUT)
    def initialize(app_root:, logger: $stdout)
      @app_root = Pathname.new(app_root)
      @logger = logger
    end

    # Generate or update the Observ controllers index file
    # @param controllers_path [String, Pathname] Path to the controllers directory
    # @return [Hash] Result of the operation
    def generate_controllers_index(controllers_path)
      controllers_path = Pathname.new(controllers_path)
      index_file = controllers_path.join("index.js")

      # Find all controller files
      controller_files = Dir.glob(controllers_path.join("*_controller.js")).sort

      if controller_files.empty?
        log "  ⚠ No controller files found in #{controllers_path}"
        return { created: false, error: "No controller files found" }
      end

      content = generate_index_content(controller_files, controllers_path)

      if index_file.exist?
        existing_content = File.read(index_file)
        if existing_content == content
          log "  - Index file already up to date: #{index_file.relative_path_from(app_root)}"
          return { created: false, updated: false, path: index_file }
        else
          log "  ✓ Updated index file: #{index_file.relative_path_from(app_root)}"
        end
      else
        log "  ✓ Created index file: #{index_file.relative_path_from(app_root)}"
      end

      File.write(index_file, content)
      { created: !index_file.exist?, updated: index_file.exist?, path: index_file }
    end

    # Check if Observ controllers are registered in the main controllers index
    # @return [Hash] Registration status and suggestions
    def check_main_controllers_registration
      main_index = app_root.join("app", "javascript", "controllers", "index.js")

      unless main_index.exist?
        return {
          registered: false,
          main_index_exists: false,
          suggestions: [
            "Main controllers index file not found at: #{main_index.relative_path_from(app_root)}",
            "You may need to manually import Observ controllers in your application"
          ]
        }
      end

      content = File.read(main_index)
      registered = content.include?("observ")

      if registered
        { registered: true, main_index_exists: true, path: main_index }
      else
        {
          registered: false,
          main_index_exists: true,
          path: main_index,
          suggestions: [
            "Add to #{main_index.relative_path_from(app_root)}:",
            "  import './observ'"
          ]
        }
      end
    end

    # Generate import statement for main controllers index
    # @param relative_path [String] Relative path to observ controllers
    # @return [String] Import statement
    def generate_import_statement(relative_path = "./observ")
      "\nimport '#{relative_path}'\n"
    end

    private

    # Generate the content for the controllers index file
    # @param controller_files [Array<String>] List of controller file paths
    # @param controllers_path [Pathname] Base path for controllers
    # @return [String] Generated content
    def generate_index_content(controller_files, controllers_path)
      imports = controller_files.map do |file|
        basename = File.basename(file)
        controller_name = basename.sub("_controller.js", "").tr("_", "-")
        class_name = basename.sub(".js", "")
          .split("_")
          .map(&:capitalize)
          .join
          .sub("Controller", "Controller")

        "import #{class_name} from \"./#{basename}\""
      end

      registrations = controller_files.map do |file|
        basename = File.basename(file)
        controller_name = basename.sub("_controller.js", "").tr("_", "-")
        class_name = basename.sub(".js", "")
          .split("_")
          .map(&:capitalize)
          .join
          .sub("Controller", "Controller")

        "application.register(\"observ--#{controller_name}\", #{class_name})"
      end

      <<~JAVASCRIPT
        // Auto-generated index file for Observ Stimulus controllers
        // Register all Observ controllers with the observ-- prefix
        import { application } from "../application"

        #{imports.join("\n")}

        #{registrations.join("\n")}
      JAVASCRIPT
    end

    # Log a message
    # @param message [String] Message to log
    def log(message)
      if logger.respond_to?(:puts)
        logger.puts(message)
      else
        logger.info(message)
      end
    end
  end
end
