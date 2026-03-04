module ExternalTodoApi
  class PullSyncFetchJob < ApplicationJob
    queue_as :external_sync

    PAYLOAD_CACHE_KEY = "pull_sync:payload"
    CACHE_TTL = 14.minutes

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform
      unless Rails.cache.read(PAYLOAD_CACHE_KEY)
        body = TodoLists.new.list.as_json
        stored = Rails.cache.write(PAYLOAD_CACHE_KEY, body, expires_in: CACHE_TTL)
        return Rails.logger.warn("PullSyncFetchJob: cache write failed, not enqueueing ProcessJob") unless stored
      end

      PullSyncProcessJob.perform_later
    end
  end
end
