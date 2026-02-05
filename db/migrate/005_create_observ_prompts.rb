class CreateObservPrompts < ActiveRecord::Migration[7.0]
  def change
    create_table :observ_prompts do |t|
      t.string :name, null: false
      t.text :prompt, null: false
      t.integer :version, null: false
      t.string :state, null: false, default: 'draft'
      t.json :config, default: {}
      t.text :commit_message
      t.string :created_by

      t.timestamps

      # Composite unique index for name + version
      t.index [:name, :version], unique: true

      # Index for state queries (e.g., find all production prompts)
      t.index [:name, :state]
    end
  end
end
