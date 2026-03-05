module Todos
  class UpdateItemService < ApplicationService
    include ActionView::RecordIdentifier
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
      broadcast_item_completed if just_completed?
      @item
    end

    private

    def item_attrs
      { description: @description, completed: @completed }.compact
    end

    def just_completed?
      @item.saved_change_to_completed? && @item.completed?
    end

    def broadcast_item_completed
      Turbo::StreamsChannel.broadcast_replace_to(
        @item.todo_list,
        target: dom_id(@item),
        partial: "items/item",
        locals: { item: @item }
      )
    end
  end
end
