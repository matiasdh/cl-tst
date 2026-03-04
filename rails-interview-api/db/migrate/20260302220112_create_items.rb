class CreateItems < ActiveRecord::Migration[7.2]
  def change
    create_table :items do |t|
      t.references :todo_list, null: false, foreign_key: true
      t.text :description, null: false
      t.boolean :completed, default: false, null: false

      t.timestamps
    end
  end
end
