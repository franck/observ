# frozen_string_literal: true

module Observ
  # Main service class for installing Observ assets in a Rails application
  class AssetInstaller
    attr_reader :gem_root, :app_root, :logger

    DEFAULT_STYLES_DEST = "app/javascript/stylesheets/observ"
    DEFAULT_JS_DEST = "app/javascript/controllers/observ"

    # @param gem_root [String, Pathname] Root directory of the gem
    # @param app_root [String, Pathname] Root directory of the host application
    # @param logger [Logger, IO] Logger for output (defaults to STDOUT)
    def initialize(gem_root:, app_root:, logger: $stdout)
      @gem_root = Pathname.new(gem_root)
      @app_root = Pathname.new(app_root)
      @logger = logger
    end

    # Install assets with custom or default destinations
    # @param styles_dest [String, nil] Custom destination for stylesheets
    # @param js_dest [String, nil] Custom destination for JavaScript controllers
    # @param generate_index [Boolean] Whether to generate index files
    # @return [Hash] Installation results
    def install(styles_dest: nil, js_dest: nil, generate_index: true)
      styles_dest ||= DEFAULT_STYLES_DEST
      js_dest ||= DEFAULT_JS_DEST

      styles_dest_path = app_root.join(styles_dest)
      js_dest_path = app_root.join(js_dest)

      log_header(styles_dest_path, js_dest_path)

      syncer = AssetSyncer.new(gem_root: gem_root, app_root: app_root, logger: logger)

      # Sync stylesheets
      styles_result = syncer.sync_stylesheets(styles_dest_path)
      log ""

      # Sync JavaScript controllers
      js_result = syncer.sync_javascript_controllers(js_dest_path)
      log ""

      # Generate index files if requested
      index_result = nil
      registration_status = nil

      if generate_index
        generator = IndexFileGenerator.new(app_root: app_root, logger: logger)

        log "Generating index files..."
        log "-" * 80
        index_result = generator.generate_controllers_index(js_dest_path)
        log ""

        log "Checking controller registration..."
        log "-" * 80
        registration_status = generator.check_main_controllers_registration

        if registration_status[:suggestions]
          registration_status[:suggestions].each { |msg| log "  #{msg}" }
        elsif registration_status[:registered]
          log "  ✓ Observ controllers are already registered"
        end
        log ""
      end

      log_footer(styles_dest_path, js_dest_path)

      {
        styles: styles_result,
        javascript: js_result,
        index: index_result,
        registration: registration_status,
        paths: {
          styles: styles_dest_path,
          javascript: js_dest_path
        }
      }
    end

    # Sync existing assets (update only)
    # @param styles_dest [String, nil] Custom destination for stylesheets
    # @param js_dest [String, nil] Custom destination for JavaScript controllers
    # @return [Hash] Sync results
    def sync(styles_dest: nil, js_dest: nil)
      install(styles_dest: styles_dest, js_dest: js_dest, generate_index: false)
    end

    private

    # Log the header with configuration info
    def log_header(styles_dest_path, js_dest_path)
      log "=" * 80
      log "Observ Asset Installation"
      log "=" * 80
      log ""
      log "Gem location: #{gem_root}"
      log "App location: #{app_root}"
      log ""
      log "Destinations:"
      log "  Styles: #{styles_dest_path.relative_path_from(app_root)}"
      log "  JavaScript: #{js_dest_path.relative_path_from(app_root)}"
      log ""
    end

    # Log the footer with next steps
    def log_footer(styles_dest_path, js_dest_path)
      log "=" * 80
      log "✓ Asset installation complete!"
      log "=" * 80
      log ""
      log "Installed to:"
      log "  Styles: #{styles_dest_path.relative_path_from(app_root)}"
      log "  JavaScript: #{js_dest_path.relative_path_from(app_root)}"
      log ""
      log "Next steps:"
      log "  1. Import the stylesheets in your application.scss or application.js"
      log "  2. Ensure the controllers index imports './observ' (see above)"
      log "  3. Restart your dev server (bin/dev)"
      log "  4. Verify assets are loaded correctly"
      log ""
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
