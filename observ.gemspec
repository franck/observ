require_relative "lib/observ/version"

Gem::Specification.new do |spec|
  spec.name        = "observ"
  spec.version     = Observ::VERSION
  spec.authors     = [ "Franck D'agostini" ]
  spec.email       = [ "franck.dagostini@gmail.com" ]
  spec.homepage    = "https://github.com/yourusername/observ"
  spec.summary     = "Rails observability engine for LLM applications"
  spec.description = "A Rails engine providing comprehensive observability for LLM-powered applications, including session tracking, trace analysis, prompt management, and cost monitoring."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0", "< 9.0"
  spec.add_dependency "kaminari", "~> 1.2"
  spec.add_dependency "aasm", "~> 5.5"

  # Development and testing
  spec.add_development_dependency "rspec-rails", "~> 7.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.0"
  spec.add_development_dependency "shoulda-matchers", "~> 7.0"
  spec.add_development_dependency "faker", "~> 3.0"
  spec.add_development_dependency "capybara"
  spec.add_development_dependency "sqlite3", ">= 1.4"
end
