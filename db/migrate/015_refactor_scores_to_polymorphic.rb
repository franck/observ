# frozen_string_literal: true

class RefactorScoresToPolymorphic < ActiveRecord::Migration[7.0]
  def change
    # Add polymorphic columns
    add_column :observ_scores, :scoreable_type, :string
    add_column :observ_scores, :scoreable_id, :bigint

    # Remove old foreign keys
    remove_foreign_key :observ_scores, :observ_dataset_run_items, column: :dataset_run_item_id
    remove_foreign_key :observ_scores, :observ_traces, column: :trace_id

    # Remove old indexes that reference the columns we're dropping
    remove_index :observ_scores, name: "idx_scores_on_run_item_name_source"
    remove_index :observ_scores, :trace_id

    # Remove old columns
    remove_column :observ_scores, :dataset_run_item_id, :bigint
    remove_column :observ_scores, :trace_id, :bigint

    # Add new indexes
    add_index :observ_scores, [ :scoreable_type, :scoreable_id ]
    add_index :observ_scores, [ :scoreable_type, :scoreable_id, :name, :source ],
              unique: true,
              name: "idx_scores_unique_on_scoreable_name_source"
  end
end
