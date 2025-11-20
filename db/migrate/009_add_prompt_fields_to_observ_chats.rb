# frozen_string_literal: true

class AddPromptFieldsToObservChats < ActiveRecord::Migration[7.0]
  def change
    # Only add columns if chats table exists (host app may not have chat feature)
    return unless table_exists?(:chats)

    add_column :chats, :prompt_name, :string, null: true
    add_column :chats, :prompt_version, :integer, null: true
  end
end
