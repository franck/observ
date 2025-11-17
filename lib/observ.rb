require "observ/version"
require "observ/engine"
require "observ/configuration"
require "observ/asset_syncer"
require "observ/asset_installer"
require "observ/index_file_generator"
require "kaminari"
require "aasm"
require "ruby_llm"
require "ruby_llm/schema"
require "csv"

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

# RubyLLM integration
require "observ/instrumenter/ruby_llm"
