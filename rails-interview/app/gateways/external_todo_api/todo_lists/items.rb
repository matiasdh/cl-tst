require_relative "../parser"

module ExternalTodoApi
  class TodoLists
    class Items
      def initialize(client)
        @client = client
      end

      def update(todo_list_id:, todo_item_id:, description: nil, completed: nil)
        body = @client.perform_request(
          :patch,
          item_path(todo_list_id:, todo_item_id:),
          { description:, completed: }.compact
        )
        Parser.parse_todo_item(body)
      end

      def delete(todo_list_id:, todo_item_id:)
        @client.perform_request(:delete, item_path(todo_list_id:, todo_item_id:))
        true
      end

      private

      def item_path(todo_list_id:, todo_item_id:)
        "/todolists/#{todo_list_id}/todoitems/#{todo_item_id}"
      end
    end
  end
end
