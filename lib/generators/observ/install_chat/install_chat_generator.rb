# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Observ
  module Generators
    # Generator for installing Observ chat/agent testing feature
    #
    # This generator enhances RubyLLM infrastructure with Observ-specific
    # agent capabilities and observability features.
    #
    # Prerequisites:
    #   - RubyLLM gem installed (gem 'ruby_llm')
    #   - rails generate ruby_llm:install (run first)
    #   - rails db:migrate
    #   - rails ruby_llm:load_models
    #
    # Usage:
    #   rails generate observ:install:chat
    #   rails generate observ:install:chat --skip-tools
    #   rails generate observ:install:chat --skip-migrations
    class InstallChatGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      class_option :skip_tools,
                   type: :boolean,
                   desc: "Skip tool class generation",
                   default: false

      class_option :skip_migrations,
                   type: :boolean,
                   desc: "Skip migration generation",
                   default: false

      class_option :skip_job,
                   type: :boolean,
                   desc: "Skip ChatResponseJob generation",
                   default: false

      class_option :with_phase_tracking,
                   type: :boolean,
                   desc: "Include phase tracking for multi-phase agents",
                   default: false

      def check_prerequisites
        say "\n"
        say "=" * 80, :cyan
        say "Observ Chat Feature Installation", :cyan
        say "=" * 80, :cyan
        say "\n"

        check_ruby_llm_gem
        check_ruby_llm_models_installed
      end

      def create_migrations
        return if options[:skip_migrations]

        say "Creating Observ-specific migrations...", :cyan
        say "-" * 80, :cyan

        migration_template "migrations/add_agent_class_name.rb.tt",
                          "db/migrate/add_agent_class_name_to_chats.rb"

        migration_template "migrations/add_observability_session_id.rb.tt",
                          "db/migrate/add_observability_session_id_to_chats.rb"

        say "  ✓ Created agent_class_name migration", :green
        say "  ✓ Created observability_session_id migration", :green
        say "\n"
      end

      def enhance_models
        say "Enhancing RubyLLM models with Observ functionality...", :cyan
        say "-" * 80, :cyan

        enhance_chat_model
        enhance_message_model

        say "\n"
      end

      def create_agent_infrastructure
        say "Creating agent infrastructure...", :cyan
        say "-" * 80, :cyan

        template "agents/base_agent.rb.tt", "app/agents/base_agent.rb"
        template "agents/agent_provider.rb.tt", "app/agents/agent_provider.rb"
        template "agents/concerns/agent_selectable.rb.tt",
                "app/agents/concerns/agent_selectable.rb"
        template "agents/concerns/prompt_management.rb.tt",
                "app/agents/concerns/prompt_management.rb"

        say "  ✓ Created BaseAgent", :green
        say "  ✓ Created AgentProvider", :green
        say "  ✓ Created AgentSelectable concern", :green
        say "  ✓ Created PromptManagement concern", :green
        say "\n"
      end

      def create_example_agent
        say "Creating example agent...", :cyan
        say "-" * 80, :cyan

        template "agents/simple_agent.rb.tt", "app/agents/simple_agent.rb"

        say "  ✓ Created SimpleAgent", :green
        say "\n"
      end

      def create_job
        return if options[:skip_job]

        say "Creating ChatResponseJob...", :cyan
        say "-" * 80, :cyan

        template "jobs/chat_response_job.rb.tt", "app/jobs/chat_response_job.rb"

        say "  ✓ Created ChatResponseJob", :green
        say "\n"
      end

      def create_tools
        return if options[:skip_tools]

        say "Creating tool classes...", :cyan
        say "-" * 80, :cyan

        template "tools/think_tool.rb.tt", "app/tools/think_tool.rb"

        say "  ✓ Created ThinkTool (basic example)", :green
        say "  ℹ For advanced tools (web search, etc.), see documentation", :yellow
        say "\n"
      end

      def create_view_partials
        say "Creating view partials...", :cyan
        say "-" * 80, :cyan

        template "views/messages/_content.html.erb.tt", "app/views/messages/_content.html.erb"

        say "  ✓ Created messages/_content partial", :green
        say "\n"
      end

      def create_initializer
        say "Creating observability initializer...", :cyan
        say "-" * 80, :cyan

        template "initializers/observability.rb.tt", "config/initializers/observability.rb"

        say "  ✓ Created observability initializer (debug logging enabled)", :green
        say "\n"
      end

      def add_phase_tracking
        return unless options[:with_phase_tracking]

        say "Adding phase tracking support...", :cyan
        say "-" * 80, :cyan

        # Call the add_phase_tracking generator
        generate "observ:add_phase_tracking"

        say "\n"
      end

      def show_post_install_instructions
        say "\n"
        say "=" * 80, :green
        say "Observ Chat Feature Installation Complete!", :green
        say "=" * 80, :green
        say "\n"

        say "Next steps:", :cyan
        say "\n"

        say "1. Run migrations:", :cyan
        say "   rails db:migrate", :white
        say "\n"

        say "2. Start your Rails server and visit:", :cyan
        say "   http://localhost:3000/observ/chats", :white
        say "\n"

        say "3. Create your first agent by extending BaseAgent:", :cyan
        say "   See app/agents/simple_agent.rb for an example", :white
        say "\n"

        unless options[:with_phase_tracking]
          say "Optional: Add phase tracking for multi-phase agents:", :cyan
          say "   rails generate observ:add_phase_tracking", :white
          say "\n"
        end

        say "Documentation:", :cyan
        say "  • Agent development: observ/docs/AGENT_DEVELOPMENT.md", :white
        say "  • Tool development: observ/docs/TOOL_DEVELOPMENT.md", :white
        say "\n"
      end

      private

      def check_ruby_llm_gem
        unless gem_installed?("ruby_llm")
          raise Thor::Error, <<~ERROR
            RubyLLM gem not found!

            This generator requires RubyLLM to be installed first.

            Please run:
              1. Add to Gemfile: gem 'ruby_llm'
              2. bundle install
              3. rails generate ruby_llm:install
              4. rails db:migrate
              5. rails ruby_llm:load_models
            #{'  '}
            Then run this generator again.
          ERROR
        end
        say "  ✓ RubyLLM gem found", :green
      end

      def check_ruby_llm_models_installed
        models_to_check = %w[Chat Message ToolCall Model]
        missing_models = []

        models_to_check.each do |model_name|
          model_path = Rails.root.join("app/models/#{model_name.underscore}.rb")
          unless File.exist?(model_path)
            missing_models << model_name
          end
        end

        if missing_models.any?
          raise Thor::Error, <<~ERROR
            RubyLLM models not found: #{missing_models.join(', ')}

            This generator requires ruby_llm:install to be run first.

            Please run:
              1. rails generate ruby_llm:install
              2. rails db:migrate
              3. rails ruby_llm:load_models
            #{'  '}
            Then run this generator again.
          ERROR
        end

        say "  ✓ RubyLLM models found (Chat, Message, ToolCall, Model)", :green
      end

      def enhance_chat_model
        concern_path = Rails.root.join("app/models/concerns/observ_chat_enhancements.rb")

        # Generate or update the concern file
        if File.exist?(concern_path)
          if options[:force]
            template "concerns/observ_chat_enhancements.rb.tt",
                    "app/models/concerns/observ_chat_enhancements.rb",
                    force: true
            say "  ✓ Overwrote ObservChatEnhancements concern", :yellow
          else
            say "  ⚠ ObservChatEnhancements concern already exists (use --force to overwrite)", :yellow
          end
        else
          template "concerns/observ_chat_enhancements.rb.tt",
                  "app/models/concerns/observ_chat_enhancements.rb"
          say "  ✓ Created ObservChatEnhancements concern", :green
        end

        # Include the concern in Chat model if not already included
        chat_content = File.read(Rails.root.join("app/models/chat.rb"))

        unless chat_content.include?("ObservChatEnhancements")
          inject_into_file "app/models/chat.rb", after: /class Chat < ApplicationRecord\n/ do
            "  include ObservChatEnhancements\n\n"
          end
          say "  ✓ Included ObservChatEnhancements in Chat model", :green
        else
          say "  ⚠ Chat model already includes ObservChatEnhancements", :yellow
        end
      end

      def enhance_message_model
        concern_path = Rails.root.join("app/models/concerns/observ_message_enhancements.rb")

        # Generate or update the concern file
        if File.exist?(concern_path)
          if options[:force]
            template "concerns/observ_message_enhancements.rb.tt",
                    "app/models/concerns/observ_message_enhancements.rb",
                    force: true
            say "  ✓ Overwrote ObservMessageEnhancements concern", :yellow
          else
            say "  ⚠ ObservMessageEnhancements concern already exists (use --force to overwrite)", :yellow
          end
        else
          template "concerns/observ_message_enhancements.rb.tt",
                  "app/models/concerns/observ_message_enhancements.rb"
          say "  ✓ Created ObservMessageEnhancements concern", :green
        end

        # Include the concern in Message model if not already included
        message_content = File.read(Rails.root.join("app/models/message.rb"))

        unless message_content.include?("ObservMessageEnhancements")
          inject_into_file "app/models/message.rb", after: /class Message < ApplicationRecord\n/ do
            "  include ObservMessageEnhancements\n\n"
          end
          say "  ✓ Included ObservMessageEnhancements in Message model", :green
        else
          say "  ⚠ Message model already includes ObservMessageEnhancements", :yellow
        end
      end

      def gem_installed?(gem_name)
        Gem::Specification.find_all_by_name(gem_name).any?
      rescue Gem::LoadError
        false
      end

      # Helper for migration timestamps
      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end
    end
  end
end
