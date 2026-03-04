module Todos
  class CreateItemService < ApplicationService
    def initialize(todo_list:, description:, completed: nil)
      @todo_list = todo_list
      @description = description
      @completed = [ true, "true" ].include?(completed)
    end

    def call
      item = @todo_list.items.create!(description: @description, completed: @completed)
      # API does not support creating items in existing lists
      item
    end
  end
end
