# frozen_string_literal: true

class CreateObservScores < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_scores do |t|
      t.references :dataset_run_item, null: false, foreign_key: { to_table: :observ_dataset_run_items }
      t.references :trace, null: false, foreign_key: { to_table: :observ_traces }
      t.references :observation, foreign_key: { to_table: :observ_observations }

      t.string :name, null: false
      t.decimal :value, precision: 10, scale: 4, null: false
      t.integer :data_type, default: 0, null: false
      t.integer :source, default: 0, null: false

      t.text :comment
      t.string :string_value
      t.string :created_by

      t.timestamps

      t.index [ :dataset_run_item_id, :name, :source ], unique: true, name: "idx_scores_on_run_item_name_source"
      t.index [ :trace_id, :name ]
      t.index :name
    end
  end
end
