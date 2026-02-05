# frozen_string_literal: true

class CreateObservDatasetItems < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_dataset_items do |t|
      t.references :dataset, null: false, foreign_key: { to_table: :observ_datasets }
      t.integer :status, default: 0, null: false
      t.json :input, null: false
      t.json :expected_output
      t.json :metadata, default: {}
      t.references :source_trace, foreign_key: { to_table: :observ_traces }
      t.timestamps

      t.index [:dataset_id, :status]
    end
  end
end
