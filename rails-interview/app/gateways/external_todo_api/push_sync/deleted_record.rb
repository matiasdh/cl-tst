module ExternalTodoApi
  module PushSync
    DeletedRecord = Data.define(:external_id, :external_source_id, :todo_list) do
      def self.build(attrs)
        attrs = attrs.symbolize_keys
        todo_list = ::TodoList.find(attrs[:todo_list_id]) if attrs[:todo_list_id]
        new(external_id: attrs[:external_id], external_source_id: attrs[:external_source_id], todo_list:)
      end
    end
  end
end
