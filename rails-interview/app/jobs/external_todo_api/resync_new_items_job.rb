module ExternalTodoApi
  class ResyncNewItemsJob < ApplicationJob
    queue_as :external_sync

    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    def perform
      Rails.logger.info("[ResyncNewItems] Job started")
      ResyncNewItemsService.new.call
      Rails.logger.info("[ResyncNewItems] Job completed")
    end
  end
end
