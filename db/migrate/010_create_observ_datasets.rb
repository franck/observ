# frozen_string_literal: true

class CreateObservDatasets < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_datasets do |t|
      t.string :name, null: false
      t.text :description
      t.string :agent_class, null: false
      t.json :metadata, default: {}
      t.timestamps

      t.index :name, unique: true
    end
  end
end
