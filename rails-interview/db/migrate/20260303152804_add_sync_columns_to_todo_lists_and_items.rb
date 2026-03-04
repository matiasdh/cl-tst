class AddSyncColumnsToTodoListsAndItems < ActiveRecord::Migration[7.2]
  def change
    add_column :todo_lists, :synced, :boolean, default: false, null: false
    add_column :todo_lists, :pending_sync_items_count, :integer, default: 0, null: false
    unless column_exists?(:todo_lists, :created_at)
      add_column :todo_lists, :created_at, :datetime, null: true, default: -> { "CURRENT_TIMESTAMP" }
    end
    unless column_exists?(:todo_lists, :updated_at)
      add_column :todo_lists, :updated_at, :datetime, null: true, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_column :items, :synced, :boolean, default: false, null: false
  end
end
