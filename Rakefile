require "bundler/setup"
require "bundler/gem_tasks"

# Load Rails tasks only when Rails is available
if defined?(Rails)
  load "rails/tasks/statistics.rake"
end

namespace :gem do
  desc "Build and install gem locally"
  task :install_local do
    Rake::Task["build"].invoke
    gem_file = Dir["*.gem"].sort_by { |f| File.mtime(f) }.last
    sh "gem install #{gem_file}"
  end

  desc "Build, tag, and push gem to RubyGems"
  task :publish do
    require_relative "lib/observ/version"
    version = Observ::VERSION
    
    puts "Publishing observ v#{version}..."
    
    # Build the gem
    puts "\n1. Building gem..."
    Rake::Task["build"].invoke
    
    # Tag the release
    puts "\n2. Creating git tag v#{version}..."
    sh "git tag -a v#{version} -m 'Release v#{version}'" rescue puts "Tag already exists"
    
    # Push gem to RubyGems
    puts "\n3. Pushing to RubyGems..."
    gem_file = "observ-#{version}.gem"
    sh "gem push #{gem_file}"
    
    # Push tags to remote
    puts "\n4. Pushing tags to remote..."
    sh "git push origin --tags"
    
    puts "\n✓ Successfully published observ v#{version}!"
    puts "  View at: https://rubygems.org/gems/observ"
  end

  desc "Clean built gems"
  task :clean do
    sh "rm -f *.gem"
  end
end
