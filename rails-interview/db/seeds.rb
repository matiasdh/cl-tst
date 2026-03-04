# Deterministic seed with Faker (2 lists, 5–10 items each).
# Seed data has no external_id/external_source_id and synced: false so it is not synced.
# Uses fixed ids and upsert_all for idempotency.
require 'faker'

seed = 20260303
list_count = 2
items_min = 5
items_max = 10

Faker::Config.random = Random.new(seed)

seed_time = Time.utc(2026, 3, 3, 0, 0, 0)

todo_list_rows = list_count.times.map do |i|
  {
    id: i + 1,
    name: Faker::Lorem.words(number: Faker::Config.random.rand(2..5)).join(' ').titleize,
    synced: false,
    created_at: seed_time,
    updated_at: seed_time
  }
end

TodoList.upsert_all(todo_list_rows, unique_by: :id)

# Deterministic item counts per list (same Faker sequence)
item_counts_per_list = list_count.times.map { Faker::Config.random.rand(items_min..items_max) }

item_rows = []
item_id = list_count + 1

item_counts_per_list.each_with_index do |items_count, list_index|
  todo_list_id = list_index + 1

  items_count.times do
    item_rows << {
      id: item_id,
      todo_list_id:,
      description: Faker::Lorem.sentence(word_count: Faker::Config.random.rand(3..10)).delete_suffix('.'),
      completed: Faker::Config.random.rand < 0.3,
      synced: false,
      created_at: seed_time,
      updated_at: seed_time
    }
    item_id += 1
  end
end

Item.upsert_all(item_rows, unique_by: :id)

# Push new todo lists to API (same as `just sync-new-lists`)
TodoList.where(external_id: [nil, '']).pluck(:id).each do |id|
  ExternalTodoApi::PushSyncJob.perform_now('TodoList', id, 'create')
end

# Enqueue initial sync: pull todo lists from API and run hourly resync
ExternalTodoApi::PullSyncFetchJob.perform_later
ExternalTodoApi::ResyncNewItemsJob.perform_later

puts "Seeded #{todo_list_rows.size} todo lists and #{item_rows.size} items (seed=#{seed})."
