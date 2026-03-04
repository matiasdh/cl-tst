class ItemsBulkUpdateJob < ApplicationJob
  include ActionView::RecordIdentifier
  include Pagy::Method
  queue_as :default

  def perform(todo_list_id, task_id, item_ids: [], all: false)
    @todo_list = TodoList.find(todo_list_id)

    scope = resolve_scope(item_ids, all)
    syncable_item_ids = scope.syncable.pluck(:id)

    scope.update_all(completed: true, synced: false, updated_at: Time.current)

    if syncable_item_ids.any?
      @todo_list.increment!(:pending_sync_items_count, syncable_item_ids.size)
      enqueue_push_sync(syncable_item_ids)
    end

    broadcast_refresh
    notify_client(task_id)
  end

  private

  def resolve_scope(item_ids, all)
    all ? @todo_list.items : @todo_list.items.where(id: item_ids)
  end

  def enqueue_push_sync(item_ids)
    item_ids.each do |item_id|
      ExternalTodoApi::PushSyncJob.perform_later("Item", item_id, "update")
    end
  end

  def notify_client(task_id)
    ActionCable.server.broadcast("bulk_update_#{task_id}", { status: "completed" })
  end

  def broadcast_refresh
    @todo_list.reload

    pagy_request = { base_url: "", path: "/todolists/#{@todo_list.id}", params: { "page" => 1 } }
    pagy_obj, items = pagy(:offset, @todo_list.items.order(id: :desc), limit: 10, page: 1, request: pagy_request)

    Turbo::StreamsChannel.broadcast_replace_to(
      @todo_list,
      target: dom_id(@todo_list, :items),
      partial: "todo_lists/items_frame",
      locals: { todo_list: @todo_list, items: items, pagy: pagy_obj }
    )

  end
end
