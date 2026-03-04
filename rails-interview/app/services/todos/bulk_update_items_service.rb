module Todos
  class BulkUpdateItemsService < ApplicationService
    def initialize(todo_list:, item_ids: [], all: false)
      @todo_list = todo_list
      @all = all
      @item_ids = item_ids
    end

    def call
      task_id = SecureRandom.uuid

      ItemsBulkUpdateJob.perform_later(
        @todo_list.id,
        task_id,
        item_ids: @item_ids,
        all: @all
      )

      task_id
    end
  end
end
