require 'faker'

seed = 20260303
list_count = 5
items_min = 10
items_max = 20
source_id = 'todo_api_seed_v1'

Faker::Config.random = Random.new(seed)

seed_time = Time.utc(2026, 3, 3, 0, 0, 0)

todo_list_external_ids = Array.new(list_count) do |i|
  "list-#{(i + 1).to_s.rjust(4, '0')}"
end

todo_list_rows = todo_list_external_ids.map do |external_id|
  name = Faker::Lorem.words(number: Faker::Config.random.rand(2..5)).join(' ').titleize

  {
    name:,
    external_source_id: source_id,
    external_id:,
    created_at: seed_time,
    updated_at: seed_time
  }
end

TodoList.upsert_all(todo_list_rows, unique_by: :index_todo_lists_on_external_source)

# We assume no todo lists exist outside this seed with the same source_id and
# external_ids, so this where returns exactly the lists we just upserted.
seeded_todo_list_ids = TodoList
  .where(external_source_id: source_id, external_id: todo_list_external_ids)
  .pluck(:id)

item_rows = []
item_counter = 0

seeded_todo_list_ids.each do |todo_list_id|
  # Only attach items to the todo lists created/updated by this seed, so that
  # any other lists already present in the DB remain untouched.
  items_count = Faker::Config.random.rand(items_min..items_max)

  items_count.times do
    item_counter += 1
    external_id = "item-#{item_counter.to_s.rjust(5, '0')}"

    item_rows << {
      todo_list_id:,
      description: Faker::Lorem.sentence(word_count: Faker::Config.random.rand(3..10)).delete_suffix('.'),
      completed: Faker::Config.random.rand < 0.3,
      external_source_id: source_id,
      external_id:,
      created_at: seed_time,
      updated_at: seed_time
    }
  end
end

Item.upsert_all(item_rows, unique_by: :index_items_on_external_source)

puts "Seeded #{todo_list_rows.size} todo lists and #{item_rows.size} items (seed=#{seed})."
