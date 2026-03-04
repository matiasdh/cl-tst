module ExternalTodoApi
  module PushSync
    class ItemHandler
      def initialize(client)
        @client = client
      end

      def call(record, action)
        if action == :create
          Rails.logger.info("[PushSync::Item] Skipping create — not supported by external API")
          return
        end

        unless syncable?(record)
          Rails.logger.info("[PushSync::Item] Skipping #{action} — item external_id=#{record.external_id.inspect} not syncable")
          return
        end

        case action
        when :update then update(record)
        when :delete then delete(record)
        end
      end

      private

      def syncable?(record)
        record.external_id.present? && record.todo_list.external_id.present?
      end

      def update(record)
        if record.synced?
          Rails.logger.info("[PushSync::Item] Skipping update — item id=#{record.id} already synced")
          record.todo_list.decrement!(:pending_sync_items_count)
          return
        end

        Rails.logger.info("[PushSync::Item] Updating item external_id=#{record.external_id} in list external_id=#{record.todo_list.external_id}")
        todo_lists.items.update(
          todo_list_id: record.todo_list.external_id,
          todo_item_id: record.external_id,
          description: record.description,
          completed: record.completed
        )
        record.update_column(:synced, true)
        record.todo_list.decrement!(:pending_sync_items_count)
      end

      def delete(record)
        Rails.logger.info("[PushSync::Item] Deleting item external_id=#{record.external_id} from list external_id=#{record.todo_list.external_id}")
        todo_lists.items.delete(
          todo_list_id: record.todo_list.external_id,
          todo_item_id: record.external_id
        )
        record.todo_list.decrement!(:pending_sync_items_count)
      end

      def todo_lists
        @todo_lists ||= TodoLists.new(@client)
      end
    end
  end
end
