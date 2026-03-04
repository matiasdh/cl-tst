module ExternalTodoApi
  class PushSyncService
    HANDLERS = {
      "TodoList" => PushSync::TodoListHandler,
      "Item" => PushSync::ItemHandler
    }.freeze

    def initialize(client: nil)
      @client = client || Client.new
    end

    def call(record, action, record_type: nil)
      type = record_type || record.class.name
      handler_class = HANDLERS.fetch(type) { raise ArgumentError, "Unsupported record type: #{type}" }
      Rails.logger.debug("[PushSync] Dispatching #{handler_class.name} for action=#{action}")
      handler_class.new(@client).call(record, action)
    end
  end
end
