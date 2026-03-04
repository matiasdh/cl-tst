class AddExternalSyncColumnsToTodoLists < ActiveRecord::Migration[7.2]
  def change
    add_column :todo_lists, :external_id, :string
    add_column :todo_lists, :external_source_id, :string
    add_index :todo_lists, [:external_source_id, :external_id], unique: true, name: "index_todo_lists_on_external_source"
  end
end
