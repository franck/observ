# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Observ
  module Generators
    # Generator for adding phase tracking to Observ chats
    #
    # This generator adds the ability to track multi-phase agent workflows
    # by adding a current_phase column and including the AgentPhaseable concern.
    #
    # Prerequisites:
    #   - Observ chat feature already installed (rails generate observ:install:chat)
    #   - Chat model exists at app/models/chat.rb
    #   - ObservChatEnhancements concern exists
    #
    # Usage:
    #   rails generate observ:add_phase_tracking
    #
    # What it does:
    #   1. Adds current_phase column to chats table
    #   2. Includes Observ::AgentPhaseable in ObservChatEnhancements
    #
    class AddPhaseTrackingGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def check_prerequisites
        say "\n"
        say "=" * 80, :cyan
        say "Adding Phase Tracking to Observ Chats", :cyan
        say "=" * 80, :cyan
        say "\n"

        check_chat_model_exists
        check_concern_exists
      end

      def create_migration
        say "Creating migration for current_phase column...", :cyan
        say "-" * 80, :cyan

        migration_template "migration.rb.tt",
                          "db/migrate/add_phase_tracking_to_chats.rb"

        say "  ✓ Created migration for current_phase column", :green
        say "\n"
      end

      def update_chat_enhancements
        say "Updating ObservChatEnhancements concern...", :cyan
        say "-" * 80, :cyan

        concern_path = Rails.root.join("app/models/concerns/observ_chat_enhancements.rb")
        concern_content = File.read(concern_path)

        if concern_content.include?("Observ::AgentPhaseable")
          say "  ⚠ AgentPhaseable already included in ObservChatEnhancements", :yellow
        else
          inject_into_file concern_path,
                          after: "include Observ::ObservabilityInstrumentation\n" do
            "    include Observ::AgentPhaseable\n"
          end
          say "  ✓ Included AgentPhaseable in ObservChatEnhancements", :green
        end

        say "\n"
      end

      def show_post_install_instructions
        say "\n"
        say "=" * 80, :green
        say "Phase Tracking Installation Complete!", :green
        say "=" * 80, :green
        say "\n"

        say "Next steps:", :cyan
        say "\n"

        say "1. Run migrations:", :cyan
        say "   rails db:migrate", :white
        say "\n"

        say "2. (Optional) Define allowed phases in your Chat model:", :cyan
        say "   # app/models/chat.rb", :white
        say "   class Chat < ApplicationRecord", :white
        say "     # ...", :white
        say "     def allowed_phases", :white
        say "       %w[scoping research writing review]", :white
        say "     end", :white
        say "   end", :white
        say "\n"

        say "3. Use phase transitions in your agents:", :cyan
        say "   chat.transition_to_phase('research')", :white
        say "   chat.in_phase?('research') # => true", :white
        say "   chat.current_phase # => 'research'", :white
        say "\n"

        say "Documentation:", :cyan
        say "  • See app/models/concerns/observ/agent_phaseable.rb for full API", :white
        say "\n"
      end

      private

      def check_chat_model_exists
        unless File.exist?(Rails.root.join("app/models/chat.rb"))
          raise Thor::Error, <<~ERROR
            Chat model not found!

            This generator requires the Chat model to exist.

            Please run:
              rails generate observ:install:chat
              rails db:migrate
            #{'  '}
            Then run this generator again.
          ERROR
        end
        say "  ✓ Chat model found", :green
      end

      def check_concern_exists
        concern_path = Rails.root.join("app/models/concerns/observ_chat_enhancements.rb")
        unless File.exist?(concern_path)
          raise Thor::Error, <<~ERROR
            ObservChatEnhancements concern not found!

            This generator requires observ:install:chat to be run first.

            Please run:
              rails generate observ:install:chat
              rails db:migrate
            #{'  '}
            Then run this generator again.
          ERROR
        end
        say "  ✓ ObservChatEnhancements concern found", :green
      end

      # Helper for migration timestamps
      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end
    end
  end
end
