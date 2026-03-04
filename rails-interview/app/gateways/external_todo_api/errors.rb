module ExternalTodoApi
  class ClientError < StandardError
    attr_reader :status, :body, :url

    def initialize(message = nil, status: nil, body: nil, url: nil)
      @status = status
      @body = body
      @url = url
      super(message || "External Todo API error: #{status} #{url}")
    end
  end

  # 4xx errors
  class NotFoundError < ClientError; end

  # 5xx errors — transient, worth retrying
  class ServerError < ClientError; end
end
