module Todos
  class DestroyItemService < ApplicationService
    include PushSyncable

    def initialize(item:)
      @item = item
    end

    def call
      if @item.external_id.present?
        @item.todo_list.increment!(:pending_sync_items_count)
      end
      enqueue_push_sync_delete(@item, todo_list_id: @item.todo_list_id)
      @item.destroy!
    end
  end
end
