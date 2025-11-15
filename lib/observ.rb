require "observ/version"
require "observ/engine"
require "observ/configuration"
require "observ/asset_syncer"
require "observ/asset_installer"
require "observ/index_file_generator"

module Observ
  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  def self.config
    self.configuration ||= Configuration.new
  end
end

# Optional RubyLLM integration
if defined?(RubyLLM)
  require "observ/instrumenter/ruby_llm"
end
