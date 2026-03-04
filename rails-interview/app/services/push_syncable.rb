module PushSyncable
  private

  def enqueue_push_sync(record, action)
    return unless record.external_id.present?

    ExternalTodoApi::PushSyncJob.perform_later(record.class.name, record.id, action.to_s)
  end

  def enqueue_push_sync_delete(record, todo_list_id: nil)
    return unless record.external_id.present?

    deleted_attrs = {
      external_id: record.external_id,
      external_source_id: record.external_source_id
    }

    deleted_attrs[:todo_list_id] = todo_list_id if todo_list_id.present?

    ExternalTodoApi::PushSyncJob.perform_later(
      record.class.name,
      nil,
      "delete",
      deleted_attrs:
    )
  end
end
