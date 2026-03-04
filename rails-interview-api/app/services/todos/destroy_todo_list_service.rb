module Todos
  class DestroyTodoListService < ApplicationService
    def initialize(todo_list:)
      @todo_list = todo_list
    end

    def call
      @todo_list.destroy!
    end
  end
end
