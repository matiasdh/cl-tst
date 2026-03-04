class RemovePendingSyncItemsCountFromTodoLists < ActiveRecord::Migration[7.2]
  def change
    remove_column :todo_lists, :pending_sync_items_count, :integer
  end
end
