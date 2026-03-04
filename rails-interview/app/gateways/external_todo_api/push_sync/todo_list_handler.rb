require_relative "../structs"

module ExternalTodoApi
  module PushSync
    class TodoListHandler
      def initialize(client)
        @client = client
      end

      def call(record, action)
        case action
        when :create then create(record)
        when :update then update(record)
        when :delete then delete(record)
        end
      end

      private

      def create(record)
        Rails.logger.info("[PushSync::TodoList] Creating list id=#{record.id} name=#{record.name.inspect}")
        payload = CreateTodoList.from_record(record)
        response = todo_lists.create(payload)
        persist_external_ids(record, response)
        Rails.logger.info("[PushSync::TodoList] Created — local_id=#{record.id} external_id=#{response.id}")
      end

      def update(record)
        unless record.external_id.present?
          Rails.logger.info("[PushSync::TodoList] Skipping update — list id=#{record.id} has no external_id")
          return
        end

        Rails.logger.info("[PushSync::TodoList] Updating list external_id=#{record.external_id}")
        todo_lists.update(id: record.external_id, name: record.name)
        record.update_column(:synced, true)
      end

      def delete(record)
        unless record.external_id.present?
          Rails.logger.info("[PushSync::TodoList] Skipping delete — record has no external_id")
          return
        end

        Rails.logger.info("[PushSync::TodoList] Deleting list external_id=#{record.external_id}")
        todo_lists.delete(id: record.external_id)
      end

      def persist_external_ids(record, response)
        record.update_columns(
          external_id: response.id.to_s,
          external_source_id: response.source_id.to_s,
          synced: true
        )

        record.items.order(:id).zip(response.items).each do |local_item, remote_item|
          next unless local_item && remote_item

          local_item.update_columns(
            external_id: remote_item.id.to_s,
            external_source_id: remote_item.source_id.to_s,
            synced: true
          )
        end
      end

      def todo_lists
        @todo_lists ||= TodoLists.new(@client)
      end
    end
  end
end
