# frozen_string_literal: true

class CreateObservReviewItems < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_review_items do |t|
      t.string :reviewable_type, null: false
      t.bigint :reviewable_id, null: false

      t.integer :status, default: 0, null: false
      t.integer :priority, default: 0, null: false

      t.string :reason
      t.json :reason_details

      t.datetime :completed_at
      t.string :completed_by

      t.timestamps

      t.index [ :reviewable_type, :reviewable_id ], unique: true, name: "idx_review_items_on_reviewable"
      t.index [ :status, :priority, :created_at ], name: "idx_review_items_on_status_priority_created"
      t.index :status
    end
  end
end
