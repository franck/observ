class AddMessageIdToObservTraces < ActiveRecord::Migration[7.0]
  def change
    add_column :observ_traces, :message_id, :integer
    add_index :observ_traces, :message_id
    add_foreign_key :observ_traces, :messages
  end
end
