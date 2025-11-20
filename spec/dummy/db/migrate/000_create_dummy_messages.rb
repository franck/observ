class CreateDummyMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :chats do |t|
      t.string :title
      t.string :agent_class_name
      t.string :observability_session_id
      t.timestamps
    end

    add_index :chats, :observability_session_id, unique: true

    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role, default: "user"
      t.text :content
      t.timestamps
    end
  end
end
