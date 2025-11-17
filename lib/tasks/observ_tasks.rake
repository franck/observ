namespace :observ do
  desc "Sync Observ engine assets (CSS and JS) to main app

  Usage:
    rails observ:sync_assets                    # Use default destinations
    rails observ:sync_assets[custom/path]       # Custom destination for styles
    rails observ:sync_assets[styles,js]         # Custom destinations for both

  Examples:
    rails observ:sync_assets
    rails observ:sync_assets[app/javascript/stylesheets/observ]
    rails observ:sync_assets[app/assets/stylesheets/observ,app/javascript/controllers/observ]
  "
  task :sync_assets, [ :styles_dest, :js_dest ] => :environment do |t, args|
    require "observ/asset_installer"

    # Get the observ gem root (this task is in observ/lib/tasks)
    # The gem is mounted as an engine within the Rails app
    observ_gem_root = Observ::Engine.root

    # Main Rails app root
    app_root = Rails.root

    # Use provided paths or let AssetInstaller use defaults
    installer = Observ::AssetInstaller.new(
      gem_root: observ_gem_root,
      app_root: app_root,
      logger: $stdout
    )

    installer.sync(
      styles_dest: args[:styles_dest],
      js_dest: args[:js_dest]
    )
  end

  desc "Install Observ assets for the first time (includes index file generation)

  Usage:
    rails observ:install_assets                 # Use default destinations
    rails observ:install_assets[custom/path]    # Custom destination for styles
    rails observ:install_assets[styles,js]      # Custom destinations for both

  Examples:
    rails observ:install_assets
    rails observ:install_assets[app/javascript/stylesheets/observ]
    rails observ:install_assets[app/assets/stylesheets/observ,app/javascript/controllers/observ]
  "
  task :install_assets, [ :styles_dest, :js_dest ] => :environment do |t, args|
    require "observ/asset_installer"

    # Get the observ gem root
    observ_gem_root = Observ::Engine.root

    # Main Rails app root
    app_root = Rails.root

    # Use provided paths or let AssetInstaller use defaults
    installer = Observ::AssetInstaller.new(
      gem_root: observ_gem_root,
      app_root: app_root,
      logger: $stdout
    )

    installer.install(
      styles_dest: args[:styles_dest],
      js_dest: args[:js_dest],
      generate_index: true
    )
  end
end

# Provide shorthand aliases
task "observ:sync" => "observ:sync_assets"
task "observ:install" => "observ:install_assets"
