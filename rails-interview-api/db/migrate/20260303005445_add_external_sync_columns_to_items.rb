class AddExternalSyncColumnsToItems < ActiveRecord::Migration[7.2]
  def change
    add_column :items, :external_id, :string
    add_column :items, :external_source_id, :string
    add_index :items, [:external_source_id, :external_id], unique: true, name: "index_items_on_external_source"
  end
end
