namespace :sync do
  desc 'Backfill pending_sync_items_count for existing todo_lists'
  task backfill_pending_sync_items_count: :environment do
    backfilled = 0
    TodoList.find_each do |todo_list|
      count = todo_list.items.where(synced: false).count
      todo_list.update_column(:pending_sync_items_count, count)
      backfilled += 1
    end
    puts "Backfilled pending_sync_items_count for #{backfilled} todo_lists"
  end
end
