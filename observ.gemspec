require_relative "lib/observ/version"

Gem::Specification.new do |spec|
  spec.name        = "observ"
  spec.version     = Observ::VERSION
  spec.authors     = [ "Franck D'agostini" ]
  spec.email       = [ "franck.dagostini@gmail.com" ]
  spec.homepage    = "https://github.com/franck/observ"
  spec.summary     = "Rails observability engine for LLM applications"
  spec.description = "A Rails engine providing comprehensive observability for LLM-powered applications. Features include session tracking, trace analysis, prompt management, cost monitoring, and optional chat/agent testing UI (with RubyLLM integration)."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0", "< 9.0"
  spec.add_dependency "kaminari", "~> 1.2"
  spec.add_dependency "aasm", "~> 5.5"
  spec.add_dependency "ruby_llm", ">= 1.0"
  spec.add_dependency "ruby_llm-schema", ">= 0.2"
  spec.add_dependency "csv", "~> 3.0"

  # Development and testing
  spec.add_development_dependency "rspec-rails", "~> 7.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.0"
  spec.add_development_dependency "shoulda-matchers", "~> 6.0"
  spec.add_development_dependency "faker", "~> 3.0"
  spec.add_development_dependency "capybara", "~> 3.0"
  spec.add_development_dependency "sqlite3", "~> 1.4"
end
