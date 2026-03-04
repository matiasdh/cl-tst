module Todos
  class UpdateTodoListService < ApplicationService
    def initialize(todo_list:, **attrs)
      @todo_list = todo_list
      @attrs = attrs
    end

    def call
      @todo_list.update!(@attrs)
      @todo_list
    end
  end
end
