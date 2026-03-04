json.id todo_list.id
json.name todo_list.name
json.items todo_list.items, partial: "api/todo_lists/items/item", as: :item
