class RemoveSyncedFromTodoListsAndItems < ActiveRecord::Migration[7.2]
  def change
    remove_column :todo_lists, :synced, :boolean
    remove_column :items, :synced, :boolean
  end
end
