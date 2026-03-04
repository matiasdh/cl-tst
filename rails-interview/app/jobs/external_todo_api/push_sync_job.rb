module ExternalTodoApi
  class PushSyncJob < ApplicationJob
    queue_as :external_sync

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    discard_on ActiveJob::DeserializationError
    discard_on ActiveRecord::RecordNotFound

    def perform(record_type, record_id, action, deleted_attrs: nil)
      Rails.logger.info("[PushSync] Job started — type=#{record_type} id=#{record_id || 'nil(deleted)'} action=#{action}")

      record = if record_id.present?
        record_type.constantize.find(record_id)
      else
        PushSync::DeletedRecord.build(deleted_attrs)
      end

      PushSyncService.new.call(record, action.to_sym, record_type:)
      Rails.logger.info("[PushSync] Job completed — type=#{record_type} id=#{record_id || 'nil(deleted)'} action=#{action}")
    rescue StandardError => e
      Rails.logger.error("[PushSync] Job failed — type=#{record_type} id=#{record_id} action=#{action} error=#{e.class}: #{e.message}")
      raise
    end
  end
end
