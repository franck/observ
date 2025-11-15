# frozen_string_literal: true

module Observ
  # Service class for syncing assets from the gem to the host application
  class AssetSyncer
    attr_reader :gem_root, :app_root, :logger

    # @param gem_root [String, Pathname] Root directory of the gem
    # @param app_root [String, Pathname] Root directory of the host application
    # @param logger [Logger, IO] Logger for output (defaults to STDOUT)
    def initialize(gem_root:, app_root:, logger: $stdout)
      @gem_root = Pathname.new(gem_root)
      @app_root = Pathname.new(app_root)
      @logger = logger
    end

    # Sync stylesheets to the destination path
    # @param dest_path [String, Pathname] Destination directory
    # @return [Hash] Statistics about the sync operation
    def sync_stylesheets(dest_path)
      source_path = gem_root.join("app", "assets", "stylesheets", "observ")
      sync_files(
        source_path: source_path,
        dest_path: Pathname.new(dest_path),
        pattern: "*.scss",
        label: "stylesheets"
      )
    end

    # Sync JavaScript controllers to the destination path
    # @param dest_path [String, Pathname] Destination directory
    # @return [Hash] Statistics about the sync operation
    def sync_javascript_controllers(dest_path)
      source_path = gem_root.join("app", "assets", "javascripts", "observ", "controllers")
      sync_files(
        source_path: source_path,
        dest_path: Pathname.new(dest_path),
        pattern: "*.js",
        label: "JavaScript controllers"
      )
    end

    private

    # Sync files matching a pattern from source to destination
    # @param source_path [Pathname] Source directory
    # @param dest_path [Pathname] Destination directory
    # @param pattern [String] File glob pattern
    # @param label [String] Human-readable label for logging
    # @return [Hash] Statistics about the sync operation
    def sync_files(source_path:, dest_path:, pattern:, label:)
      log "Syncing Observ #{label}..."
      log "-" * 80

      unless source_path.directory?
        log "  ⚠ Source #{label} directory not found: #{source_path}"
        return { files_copied: 0, files_skipped: 0, error: "Source directory not found" }
      end

      # Ensure destination directory exists
      FileUtils.mkdir_p(dest_path)

      files_copied = 0
      files_skipped = 0

      Dir.glob(source_path.join(pattern)).sort.each do |file|
        filename = File.basename(file)
        dest_file = dest_path.join(filename)

        if should_copy_file?(file, dest_file)
          FileUtils.cp(file, dest_file)
          log "  ✓ Copied #{filename}"
          files_copied += 1
        else
          log "  - Skipped #{filename} (no changes)"
          files_skipped += 1
        end
      end

      log ""
      log "  Total: #{files_copied} file(s) updated, #{files_skipped} file(s) skipped"

      { files_copied: files_copied, files_skipped: files_skipped }
    end

    # Determine if a file should be copied
    # @param source_file [String] Path to source file
    # @param dest_file [Pathname] Path to destination file
    # @return [Boolean] true if file should be copied
    def should_copy_file?(source_file, dest_file)
      !dest_file.exist? || !FileUtils.identical?(source_file, dest_file.to_s)
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
