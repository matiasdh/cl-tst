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
      broadcast_refresh_items
      item
    end

    private

    def broadcast_refresh_items
      ActionCable.server.broadcast("todo_list_#{@todo_list.id}", { action: "refresh_items" })
    end
  end
end
