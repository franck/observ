class CreateObservObservations < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_observations do |t|
      t.string :observation_id, null: false
      t.references :observ_trace, null: false, foreign_key: true
      t.string :parent_observation_id
      t.string :type, null: false
      t.string :name
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.json :metadata, default: {}
      t.string :level, default: 'DEFAULT'
      t.string :status_message
      t.string :version

      # Generation-specific fields
      t.string :model
      t.json :model_parameters, default: {}
      t.text :input
      t.text :output
      t.json :usage, default: {}
      t.decimal :cost_usd, precision: 10, scale: 6
      t.string :prompt_name
      t.string :prompt_version
      t.datetime :completion_start_time
      t.string :finish_reason
      t.json :provider_metadata, default: {}
      t.json :messages, default: []
      t.json :tools, default: []
      t.string :tool_choice
      t.json :raw_response

      t.timestamps
    end

    add_index :observ_observations, :observation_id, unique: true
    add_index :observ_observations, :parent_observation_id
    add_index :observ_observations, :type
    add_index :observ_observations, :name
    add_index :observ_observations, :start_time
  end
end
