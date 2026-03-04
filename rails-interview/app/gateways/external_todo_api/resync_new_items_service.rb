module ExternalTodoApi
  class ResyncNewItemsService
    def initialize(client: nil)
      @client = client || Client.new
    end

    def call
      lists_needing_resync.find_each do |todo_list|
        resync(todo_list)
      rescue StandardError => e
        Rails.logger.error("[ResyncNewItems] Failed for list id=#{todo_list.id} — #{e.class}: #{e.message}")
      end
    end

    private

    def lists_needing_resync
      ::TodoList.where.not(external_id: [nil, ""])
                .joins(:items)
                .where(items: { external_id: [nil, ""] })
                .distinct
    end

    def resync(todo_list)
      Rails.logger.info("[ResyncNewItems] Resyncing list id=#{todo_list.id} external_id=#{todo_list.external_id}")

      begin
        todo_lists.delete(id: todo_list.external_id)
        Rails.logger.info("[ResyncNewItems] Deleted remote list external_id=#{todo_list.external_id}")
      rescue NotFoundError => e
        Rails.logger.warn(
          "[ResyncNewItems] Remote list not found for delete external_id=#{todo_list.external_id} — #{e.class}: #{e.message}"
        )
      end

      payload = CreateTodoList.from_record(todo_list)
      response = todo_lists.create(payload)
      Rails.logger.info("[ResyncNewItems] Recreated remote list — new external_id=#{response.id}")

      persist_external_ids(todo_list, response)
    end

    def persist_external_ids(record, response)
      record.update_columns(
        external_id: response.id.to_s,
        external_source_id: response.source_id.to_s,
        synced: true,
        pending_sync_items_count: 0
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
