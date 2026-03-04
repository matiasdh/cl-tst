module Todos
  class UpdateItemService < ApplicationService
    def initialize(item:, description: nil, completed: nil)
      @item = item
      @description = description
      @completed = completed
    end

    def call
      @item.update!(item_attrs)
      @item
    end

    private

    def item_attrs
      { description: @description, completed: @completed }.compact
    end
  end
end
