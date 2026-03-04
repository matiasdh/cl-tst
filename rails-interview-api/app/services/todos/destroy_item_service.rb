module Todos
  class DestroyItemService < ApplicationService
    def initialize(item:)
      @item = item
    end

    def call
      @item.destroy!
    end
  end
end
