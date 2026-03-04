module Todos
  class CreateTodoListService < ApplicationService
    def initialize(name:, source_id: nil, items: [])
      @name = name
      @source_id = source_id
      @items = items.to_a
    end

    def call
      todo_list = TodoList.create!(
        name: @name,
        external_source_id: @source_id.presence
      )
      create_items(todo_list)
      todo_list.reload
    end

    private

    def create_items(todo_list)
      @items.each do |item_attrs|
        attrs = item_attrs.to_h.with_indifferent_access
        todo_list.items.create!(
          description: attrs[:description].to_s.presence || 'Untitled',
          completed: [ true, 'true', '1' ].include?(attrs[:completed]),
          external_source_id: attrs[:source_id].presence
        )
      end
    end
  end
end
