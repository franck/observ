class CreateObservTraces < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_traces do |t|
      t.string :trace_id, null: false
      t.references :observ_session, null: false, foreign_key: true
      t.string :name
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.text :input
      t.text :output
      t.json :metadata, default: {}
      t.json :tags, default: []
      t.string :user_id
      t.string :release
      t.string :version
      t.decimal :total_cost, precision: 10, scale: 6, default: 0.0
      t.integer :total_tokens, default: 0

      t.timestamps
    end
    add_index :observ_traces, :trace_id, unique: true
    add_index :observ_traces, :name
    add_index :observ_traces, :start_time
  end
end
