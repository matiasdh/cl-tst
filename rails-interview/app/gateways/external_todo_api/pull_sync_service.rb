module ExternalTodoApi
  class PullSyncService
    BATCH_SIZE_TODO_LISTS = 50
    BATCH_SIZE_ITEMS = 200

    def call(raw_lists)
      Rails.logger.info("[PullSync] Starting pull sync — #{raw_lists.size} list(s) from external API")

      sync_todo_lists(raw_lists)
      Rails.logger.info("[PullSync] Upserted #{raw_lists.size} todo list(s)")

      todo_list_ids_by_external_ids = lookup_todo_list_ids(raw_lists)
      item_count = raw_lists.sum { |l| l.items.size }
      sync_items(raw_lists, todo_list_ids_by_external_ids)
      Rails.logger.info("[PullSync] Upserted #{item_count} item(s) across #{todo_list_ids_by_external_ids.size} resolved list(s)")

      Rails.logger.info("[PullSync] Pull sync completed successfully")
      true
    end

    private

    def sync_todo_lists(raw_lists)
      raw_lists.each_slice(BATCH_SIZE_TODO_LISTS).each do |raw_list_batch|
        rows = raw_list_batch.map { |raw_list| build_todo_list_row(raw_list) }
        # On conflict: skip update when existing row has synced = false (preserve local changes)
        ::TodoList.import(rows,
          on_duplicate_key_update: {
            conflict_target: [ :external_source_id, :external_id ],
            columns: [ :name, :synced, :updated_at ],
            condition: "#{::TodoList.quoted_table_name}.synced = 1"
          },
          validate: false
        )
      end
    end

    def lookup_todo_list_ids(raw_lists)
      source_ids = raw_lists.map(&:source_id).uniq
      external_ids = raw_lists.map(&:id).uniq
      return {} if source_ids.empty?

      ::TodoList.where(external_source_id: source_ids, external_id: external_ids)
        .pluck(:external_source_id, :external_id, :id)
        .to_h { |external_source_id, external_id, todo_list_id| [ [ external_source_id, external_id ], todo_list_id ] }
    end

    def build_todo_list_row(raw_list)
      now = Time.current
      {
        name: raw_list.name,
        external_id: raw_list.id.to_s,
        external_source_id: raw_list.source_id.to_s,
        synced: true,
        created_at: parse_time(raw_list.created_at) || now,
        updated_at: parse_time(raw_list.updated_at) || now
      }
    end

    def sync_items(raw_lists, todo_list_ids_by_external_ids)
      rows = prepare_item_rows(raw_lists, todo_list_ids_by_external_ids)

      rows.each_slice(BATCH_SIZE_ITEMS).each do |batch|
        next if batch.empty?

        # On conflict: skip update when existing row has synced = false (preserve local changes)
        ::Item.import(batch,
          on_duplicate_key_update: {
            conflict_target: [ :external_source_id, :external_id ],
            columns: [ :description, :completed, :synced, :updated_at ],
            condition: "#{::Item.quoted_table_name}.synced = 1"
          },
          validate: false
        )
      end
    end

    def prepare_item_rows(raw_lists, todo_list_ids_by_external_ids)
      raw_lists.flat_map do |raw_list|
        todo_list_id = todo_list_ids_by_external_ids[[ raw_list.source_id.to_s, raw_list.id.to_s ]]
        next [] unless todo_list_id

        raw_list.items.map { |raw_item| build_item_row(raw_item, todo_list_id) }
      end
    end

    def build_item_row(raw_item, todo_list_id)
      now = Time.current
      {
        todo_list_id:,
        description: raw_item.description,
        completed: raw_item.completed,
        external_id: raw_item.id.to_s,
        external_source_id: raw_item.source_id.to_s,
        synced: true,
        created_at: parse_time(raw_item.created_at) || now,
        updated_at: parse_time(raw_item.updated_at) || now
      }
    end

    def parse_time(value)
      return nil if value.blank?

      value.is_a?(String) ? Time.zone.parse(value) : value
    end
  end
end
