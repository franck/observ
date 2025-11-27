# frozen_string_literal: true

require "rails/generators"
require "observ/asset_installer"

module Observ
  module Generators
    # Generator for installing Observ assets in a Rails application
    #
    # Usage:
    #   rails generate observ:install
    #   rails generate observ:install --styles-dest=custom/path
    #   rails generate observ:install --js-dest=custom/path
    #   rails generate observ:install --skip-index
    #   rails generate observ:install --skip-routes  # Don't auto-mount engine
    #   rails generate observ:install --force        # Skip confirmation prompt
    #   rails generate observ:install --skip-vite-entrypoint  # Don't generate Vite entry point
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      class_option :styles_dest,
                   type: :string,
                   desc: "Destination path for stylesheets (default: app/javascript/stylesheets/observ)",
                   default: nil

      class_option :js_dest,
                   type: :string,
                   desc: "Destination path for JavaScript controllers (default: app/javascript/controllers/observ)",
                   default: nil

      class_option :skip_index,
                   type: :boolean,
                   desc: "Skip generation of index files (default: true, index.js no longer needed)",
                   default: true

      class_option :force,
                   type: :boolean,
                   desc: "Skip confirmation prompt",
                   default: false

      class_option :skip_routes,
                   type: :boolean,
                   desc: "Skip automatic route mounting",
                   default: false

      class_option :skip_vite_entrypoint,
                   type: :boolean,
                   desc: "Skip generation of Vite entry point",
                   default: false

      class_option :vite_entrypoint_dest,
                   type: :string,
                   desc: "Destination path for Vite entry point (default: app/javascript/entrypoints)",
                   default: "app/javascript/entrypoints"

      def confirm_installation
        return if options[:force]

        styles_dest = options[:styles_dest] || Observ::AssetInstaller::DEFAULT_STYLES_DEST
        js_dest = options[:js_dest] || Observ::AssetInstaller::DEFAULT_JS_DEST

        say "\n"
        say "=" * 80, :cyan
        say "Observ Installation", :cyan
        say "=" * 80, :cyan
        say "\n"

        # Collect files that will actually be copied
        stylesheets_to_copy = collect_files_to_copy("stylesheets", "*.scss", styles_dest)
        js_files_to_copy = collect_files_to_copy("javascripts", "*.js", js_dest)
        index_will_be_generated = !options[:skip_index] && will_generate_index?(js_dest)
        route_will_be_added = !options[:skip_routes] && !route_already_exists?
        vite_entrypoint_will_be_created = !options[:skip_vite_entrypoint] && will_create_vite_entrypoint?

        # Check if there are any changes to make
        total_changes = stylesheets_to_copy.count + js_files_to_copy.count +
                       (index_will_be_generated ? 1 : 0) + (route_will_be_added ? 1 : 0) +
                       (vite_entrypoint_will_be_created ? 1 : 0)

        if total_changes == 0
          say "No changes needed - all files are up to date!", :green
          say "\n"
          return
        end

        say "The following changes will be made:", :yellow
        say "\n"

        # Show stylesheet files that will be copied
        if stylesheets_to_copy.any?
          say "Stylesheets (#{stylesheets_to_copy.count} files to #{styles_dest}):", :yellow
          stylesheets_to_copy.each do |file|
            say "  • #{File.basename(file)}", :white
          end
          say "\n"
        end

        # Show JavaScript files that will be copied
        if js_files_to_copy.any?
          say "JavaScript Controllers (#{js_files_to_copy.count} files to #{js_dest}):", :yellow
          js_files_to_copy.each do |file|
            say "  • #{File.basename(file)}", :white
          end
          say "\n"
        end

        # Show generated files
        generated_files = []
        generated_files << "#{js_dest}/index.js (controller index)" if index_will_be_generated
        generated_files << "#{options[:vite_entrypoint_dest]}/observ.js (Vite entry point)" if vite_entrypoint_will_be_created

        if generated_files.any?
          say "Generated Files:", :yellow
          generated_files.each { |file| say "  • #{file}", :white }
          say "\n"
        end

        # Show routes
        if route_will_be_added
          say "Routes (will be added to config/routes.rb):", :yellow
          say '  mount Observ::Engine, at: "/observ"', :white
          say "\n"
        elsif !options[:skip_routes]
          say "Routes:", :green
          say "  Engine already mounted in config/routes.rb", :green
          say "\n"
        end

        unless yes?("Do you want to proceed with the installation? (y/n)", :yellow)
          say "\nInstallation cancelled.", :red
          exit 0
        end
        say "\n"
      end

      def mount_engine
        return if options[:skip_routes]

        say "Checking routes...", :cyan
        say "-" * 80, :cyan

        if route_already_exists?
          say "  Engine already mounted in config/routes.rb", :yellow
        else
          route 'mount Observ::Engine, at: "/observ"'
          say "  ✓ Added route: mount Observ::Engine, at: \"/observ\"", :green
        end
        say "\n"
      end

      def install_assets
        installer = Observ::AssetInstaller.new(
          gem_root: Observ::Engine.root,
          app_root: Rails.root,
          logger: GeneratorLogger.new(self)
        )

        @result = installer.install(
          styles_dest: options[:styles_dest],
          js_dest: options[:js_dest],
          generate_index: !options[:skip_index]
        )
      end

      def install_vite_entrypoint
        return if options[:skip_vite_entrypoint]

        dest_dir = Rails.root.join(options[:vite_entrypoint_dest])
        dest_file = dest_dir.join("observ.js")

        if dest_file.exist?
          say "  Vite entry point already exists: #{dest_file}", :yellow
          return
        end

        say "Creating Vite entry point...", :cyan
        say "-" * 80, :cyan

        FileUtils.mkdir_p(dest_dir)
        copy_file "observ.js", dest_file
        say "  Created #{dest_file}", :green
        say "\n"
      end

      def show_post_install_message
        say "\n"
        say "=" * 80, :green
        say "Observ installed successfully!", :green
        say "=" * 80, :green
        say "\n"

        if @result[:registration] && @result[:registration][:suggestions]
          say "⚠ Action required:", :yellow
          @result[:registration][:suggestions].each do |suggestion|
            say "  #{suggestion}", :yellow
          end
          say "\n"
        end

        say "Next steps:", :cyan

        if options[:skip_vite_entrypoint]
          say "  1. Import Observ in your application", :cyan
          say "     Add to app/javascript/application.js:", :cyan
          say "     import 'observ'", :cyan
          say "\n"
        else
          say "  1. Add 'observ' to your Vite entrypoints (if not auto-detected)", :cyan
          say "     The entry point was created at: #{options[:vite_entrypoint_dest]}/observ.js", :cyan
          say "\n"
        end

        say "  2. Restart your development server", :cyan
        say "     bin/dev or rails server", :cyan
        say "\n"
        say "  3. Visit /observ in your browser", :cyan
        unless options[:skip_routes]
          say "     (Engine mounted at /observ)", :cyan
        end
        say "\n"
      end

      private

      def route_already_exists?
        routes_file = Rails.root.join("config/routes.rb")
        return false unless routes_file.exist?

        routes_content = File.read(routes_file)
        routes_content.match?(/mount\s+Observ::Engine/)
      end

      # Collect only files that will actually be copied (new or modified)
      # @param asset_type [String] "stylesheets" or "javascripts"
      # @param pattern [String] File glob pattern (e.g., "*.scss", "*.js")
      # @param dest_path [String] Destination directory path
      # @return [Array<String>] List of source file paths that will be copied
      def collect_files_to_copy(asset_type, pattern, dest_path)
        source_path = get_source_path(asset_type)
        return [] unless source_path.directory?

        dest_path = Rails.root.join(dest_path)

        files_to_copy = []
        Dir.glob(source_path.join(pattern)).sort.each do |source_file|
          filename = File.basename(source_file)
          dest_file = dest_path.join(filename)

          if should_copy_file?(source_file, dest_file)
            files_to_copy << source_file
          end
        end

        files_to_copy
      end

      # Get the source path for the given asset type
      # @param asset_type [String] "stylesheets" or "javascripts"
      # @return [Pathname] Source directory path
      def get_source_path(asset_type)
        if asset_type == "stylesheets"
          Observ::Engine.root.join("app", "assets", "stylesheets", "observ")
        else
          Observ::Engine.root.join("app", "assets", "javascripts", "observ", "controllers")
        end
      end

      # Determine if a file should be copied (matches AssetSyncer logic)
      # @param source_file [String] Path to source file
      # @param dest_file [Pathname] Path to destination file
      # @return [Boolean] true if file should be copied
      def should_copy_file?(source_file, dest_file)
        !dest_file.exist? || !FileUtils.identical?(source_file, dest_file.to_s)
      end

      # Check if index.js will be generated (new or different content)
      # @param js_dest [String] Destination path for JavaScript controllers
      # @return [Boolean] true if index.js will be generated
      def will_generate_index?(js_dest)
        index_file = Rails.root.join(js_dest, "index.js")
        # Index file will be generated if it doesn't exist
        # (we don't check content as the generator always creates it)
        !index_file.exist?
      end

      # Check if Vite entry point will be created
      # @return [Boolean] true if observ.js will be created
      def will_create_vite_entrypoint?
        dest_file = Rails.root.join(options[:vite_entrypoint_dest], "observ.js")
        !dest_file.exist?
      end

      # Logger adapter for Rails generator
      class GeneratorLogger
        def initialize(generator)
          @generator = generator
        end

        def puts(message)
          # Remove color codes and special characters for cleaner output
          clean_message = message.gsub(/[✓✗⚠-]/, "").strip

          if message.include?("✓") || message.include?("Copied")
            @generator.say("  #{clean_message}", :green)
          elsif message.include?("⚠")
            @generator.say("  #{clean_message}", :yellow)
          elsif message.include?("=") || message.start_with?("Syncing", "Generating", "Checking")
            @generator.say(clean_message, :cyan)
          elsif message.include?("Skipped")
            @generator.say("  #{clean_message}", :white)
          else
            @generator.say(clean_message)
          end
        end

        def info(message)
          puts(message)
        end
      end
    end
  end
end
