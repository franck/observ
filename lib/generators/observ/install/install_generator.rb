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
                   desc: "Skip generation of index files",
                   default: false

      class_option :force,
                   type: :boolean,
                   desc: "Skip confirmation prompt",
                   default: false

      class_option :skip_routes,
                   type: :boolean,
                   desc: "Skip automatic route mounting",
                   default: false

      def confirm_installation
        return if options[:force]

        styles_dest = options[:styles_dest] || Observ::AssetInstaller::DEFAULT_STYLES_DEST
        js_dest = options[:js_dest] || Observ::AssetInstaller::DEFAULT_JS_DEST

        say "\n"
        say "=" * 80, :cyan
        say "Observ Asset Installation", :cyan
        say "=" * 80, :cyan
        say "\n"
        say "The following changes will be made:", :yellow
        say "\n"
        say "Assets will be copied to:", :yellow
        say "  Stylesheets: #{styles_dest}", :yellow
        say "  JavaScript:  #{js_dest}", :yellow
        say "\n"

        unless options[:skip_routes]
          if route_already_exists?
            say "Routes:", :yellow
            say "  Engine already mounted in config/routes.rb", :yellow
          else
            say "Routes (will be added to config/routes.rb):", :yellow
            say '  mount Observ::Engine, at: "/observ"', :yellow
          end
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
        say "  1. Import stylesheets in your application", :cyan
        say "     Add to app/javascript/application.js:", :cyan
        say "     import 'observ'", :cyan
        say "\n"
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
