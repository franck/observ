# frozen_string_literal: true

class CreateObservDatasetRuns < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_dataset_runs do |t|
      t.references :dataset, null: false, foreign_key: { to_table: :observ_datasets }
      t.string :name, null: false
      t.text :description
      t.integer :status, default: 0, null: false
      t.json :metadata, default: {}
      t.integer :total_items, default: 0
      t.integer :completed_items, default: 0
      t.integer :failed_items, default: 0
      t.decimal :total_cost, precision: 10, scale: 6, default: 0
      t.integer :total_tokens, default: 0
      t.timestamps

      t.index [ :dataset_id, :name ], unique: true
      t.index [ :dataset_id, :status ]
    end
  end
end
