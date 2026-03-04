module Todos
  class UpdateItemService < ApplicationService
    include PushSyncable

    def initialize(item:, description: nil, completed: nil)
      @item = item
      @description = description
      @completed = completed
    end

    def call
      @item.update!(item_attrs.merge(synced: false))
      if @item.external_id.present?
        @item.todo_list.increment!(:pending_sync_items_count)
        enqueue_push_sync(@item, :update)
      end
      @item
    end

    private

    def item_attrs
      { description: @description, completed: @completed }.compact
    end
  end
end
