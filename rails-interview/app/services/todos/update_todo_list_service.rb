module Todos
  class UpdateTodoListService < ApplicationService
    include PushSyncable

    def initialize(todo_list:, **attrs)
      @todo_list = todo_list
      @attrs = attrs.merge(synced: false)
    end

    def call
      @todo_list.update!(@attrs)
      enqueue_push_sync(@todo_list, :update)
      @todo_list
    end
  end
end
