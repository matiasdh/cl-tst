require_relative "client"
require_relative "parser"
require_relative "todo_lists/items"

module ExternalTodoApi
  class TodoLists
    def initialize(client = nil)
      @client = client || Client.new
    end

    def list
      body = @client.perform_request(:get, root_path)
      Parser.parse_todo_lists(body)
    end

    def create(payload)
      body = @client.perform_request(:post, root_path, payload.as_json)
      Parser.parse_todo_list(body)
    end

    def update(id:, name:)
      body = @client.perform_request(:patch, todo_list_path(id:), { name: }.compact)
      Parser.parse_todo_list(body)
    end

    def delete(id:)
      @client.perform_request(:delete, todo_list_path(id:))
      true
    end

    def items
      TodoLists::Items.new(@client)
    end

    private

    def root_path
      "/todolists"
    end

    def todo_list_path(id:)
      "/todolists/#{id}"
    end
  end
end
