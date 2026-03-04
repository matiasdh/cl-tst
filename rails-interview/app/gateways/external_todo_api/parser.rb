require_relative "structs"

module ExternalTodoApi
  class Parser
    # GET /todolists returns array of list hashes
    def self.parse_todo_lists(body)
      Array(body).map { |h| parse_todo_list(h) }
    end

    def self.parse_todo_list(hash)
      return nil if hash.nil?

      h = normalize(hash)
      items = h.fetch(:items, []).map { |i| parse_todo_item(i) }
      list_attrs = TodoList.members - [:items]
      attrs = h.slice(*list_attrs).merge(items:)
      TodoList.new(**attrs)
    end

    def self.parse_todo_item(hash)
      return nil if hash.nil?

      TodoItem.new(**normalize(hash).slice(*TodoItem.members))
    end

    # Handles string or symbol keys (JSON returns strings)
    def self.normalize(hash)
      hash.with_indifferent_access
    end
  end
end
