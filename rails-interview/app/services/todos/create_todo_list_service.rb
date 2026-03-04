module Todos
  class CreateTodoListService < ApplicationService
    def initialize(name:)
      @name = name
    end

    def call
      todo_list = TodoList.create!(name: @name)
      ExternalTodoApi::PushSyncJob.perform_later(todo_list.class.name, todo_list.id, 'create')
      todo_list
    end

    private
  end
end
