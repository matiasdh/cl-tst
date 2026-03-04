module Todos
  class DestroyTodoListService < ApplicationService
    include PushSyncable

    def initialize(todo_list:)
      @todo_list = todo_list
    end

    def call
      enqueue_push_sync_delete(@todo_list)
      @todo_list.destroy!
    end
  end
end
