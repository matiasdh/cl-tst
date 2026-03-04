json.id todo_list.id.to_s
json.source_id todo_list.external_source_id if todo_list.external_source_id.present?
json.name todo_list.name
json.created_at todo_list.created_at&.iso8601
json.updated_at todo_list.updated_at&.iso8601
json.items todo_list.items, partial: 'api/todo_lists/items/item', as: :item
