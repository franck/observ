class CreateObservSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :observ_sessions do |t|
      t.string :session_id, null: false
      t.string :user_id
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.json :metadata, default: {}
      t.integer :total_traces_count, default: 0
      t.integer :total_llm_calls_count, default: 0
      t.integer :total_tokens, default: 0
      t.decimal :total_cost, precision: 10, scale: 6, default: 0.0
      t.integer :total_llm_duration_ms, default: 0

      t.timestamps
    end
    add_index :observ_sessions, :session_id, unique: true
    add_index :observ_sessions, :user_id
    add_index :observ_sessions, :start_time
  end
end
