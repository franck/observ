class FixPromptConfigStrings < ActiveRecord::Migration[8.0]
  def up
    # Find all prompts where config is stored as a String instead of JSON
    Observ::Prompt.find_each do |prompt|
      next if prompt.config.nil?

      if prompt.config.is_a?(String)
        begin
          parsed = JSON.parse(prompt.config)
          prompt.update_column(:config, parsed)
          puts "Fixed config for #{prompt.name} v#{prompt.version}"
        rescue JSON::ParserError => e
          puts "WARNING: Could not parse config for #{prompt.name} v#{prompt.version}: #{e.message}"
          prompt.update_column(:config, {})
        end
      end
    end
  end

  def down
    # No need to reverse this - we're fixing data corruption
  end
end
