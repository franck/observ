# frozen_string_literal: true

class CreateObservDatasetRunItems < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_dataset_run_items do |t|
      t.references :dataset_run, null: false, foreign_key: { to_table: :observ_dataset_runs }
      t.references :dataset_item, null: false, foreign_key: { to_table: :observ_dataset_items }
      t.references :trace, foreign_key: { to_table: :observ_traces }
      t.references :observation, foreign_key: { to_table: :observ_observations }
      t.text :error
      t.timestamps

      t.index [:dataset_run_id, :dataset_item_id], unique: true, name: "idx_run_items_on_run_and_item"
    end
  end
end
