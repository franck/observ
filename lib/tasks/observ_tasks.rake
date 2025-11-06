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
    require "fileutils"

    # Get the observ gem root (this task is in observ/lib/tasks)
    # The gem is mounted as an engine within the Rails app
    observ_gem_root = Rails.root.join("observ")

    # Main Rails app root
    app_root = Rails.root

    # Define default destination paths (relative to main app)
    default_styles_dest = "app/javascript/stylesheets/observ"
    default_js_dest = "app/javascript/controllers/observ"

    # Use provided paths or defaults
    styles_dest = args[:styles_dest] || default_styles_dest
    js_dest = args[:js_dest] || default_js_dest

    # Convert to absolute paths
    styles_dest_path = app_root.join(styles_dest)
    js_dest_path = app_root.join(js_dest)

    puts "=" * 80
    puts "Observ Asset Sync"
    puts "=" * 80
    puts ""
    puts "Gem location: #{observ_gem_root}"
    puts "App location: #{app_root}"
    puts ""

    # Sync stylesheets
    sync_stylesheets(observ_gem_root, styles_dest_path)

    puts ""

    # Sync JavaScript controllers
    sync_javascript_controllers(observ_gem_root, js_dest_path)

    puts ""
    puts "=" * 80
    puts "✓ Asset sync complete!"
    puts "=" * 80
    puts ""
    puts "Synced to:"
    puts "  Styles: #{styles_dest_path.relative_path_from(app_root)}"
    puts "  JavaScript: #{js_dest_path.relative_path_from(app_root)}"
    puts ""
    puts "Next steps:"
    puts "  1. Restart your dev server (bin/dev)"
    puts "  2. Verify assets are loaded correctly"
    puts ""
  end

  def sync_stylesheets(observ_gem_root, dest_path)
    puts "Syncing Observ stylesheets..."
    puts "-" * 80

    source_path = File.join(observ_gem_root, "app", "assets", "stylesheets", "observ")

    unless File.directory?(source_path)
      puts "  ⚠ Source stylesheets directory not found: #{source_path}"
      return
    end

    FileUtils.mkdir_p(dest_path)

    files_copied = 0
    Dir.glob(File.join(source_path, "*.scss")).sort.each do |file|
      filename = File.basename(file)
      dest_file = File.join(dest_path, filename)

      # Check if file is different before copying
      if !File.exist?(dest_file) || !FileUtils.identical?(file, dest_file)
        FileUtils.cp(file, dest_file)
        puts "  ✓ Copied #{filename}"
        files_copied += 1
      else
        puts "  - Skipped #{filename} (no changes)"
      end
    end

    puts ""
    puts "  Total: #{files_copied} file(s) updated"
  end

  def sync_javascript_controllers(observ_gem_root, dest_path)
    puts "Syncing Observ JavaScript controllers..."
    puts "-" * 80

    source_path = File.join(observ_gem_root, "app", "assets", "javascripts", "observ", "controllers")

    unless File.directory?(source_path)
      puts "  ⚠ Source controllers directory not found: #{source_path}"
      return
    end

    FileUtils.mkdir_p(dest_path)

    files_copied = 0
    Dir.glob(File.join(source_path, "*.js")).sort.each do |file|
      filename = File.basename(file)
      dest_file = File.join(dest_path, filename)

      # Check if file is different before copying
      if !File.exist?(dest_file) || !FileUtils.identical?(file, dest_file)
        FileUtils.cp(file, dest_file)
        puts "  ✓ Copied #{filename}"
        files_copied += 1
      else
        puts "  - Skipped #{filename} (no changes)"
      end
    end

    puts ""
    puts "  Total: #{files_copied} file(s) updated"

    # Provide guidance about controller registration
    check_controller_registration(Rails.root, dest_path)
  end

  def check_controller_registration(app_root, controllers_path)
    index_file = File.join(app_root, "app", "javascript", "controllers", "index.js")

    unless File.exist?(index_file)
      puts ""
      puts "  ℹ Note: app/javascript/controllers/index.js not found"
      puts "  You may need to manually import Observ controllers in your application"
      return
    end

    content = File.read(index_file)

    # Check if observ controllers are referenced
    unless content.include?("observ")
      puts ""
      puts "  ⚠ Observ controllers may need to be registered"
      puts "  Consider adding to app/javascript/controllers/index.js:"
      puts "    import './observ'"
      puts ""
      puts "  Or create app/javascript/controllers/observ/index.js with:"
      puts "    // Register all Observ controllers with observ-- prefix"
    end
  end
end

# Provide shorthand alias
task "observ:sync" => "observ:sync_assets"
