module ExternalTodoApi
  class PullSyncProcessJob < ApplicationJob
    queue_as :external_sync

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    discard_on ActiveJob::DeserializationError

    def perform
      payload = Rails.cache.read(PullSyncFetchJob::PAYLOAD_CACHE_KEY)

      if payload.nil?
        Rails.logger.warn("PullSyncProcessJob: payload expired or missing")
      else
        lists = Parser.parse_todo_lists(payload)
        PullSyncService.new.call(lists)
      end
    end
  end
end
