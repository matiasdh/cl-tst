require "faraday"
require "faraday/retry"

require_relative "errors"

module ExternalTodoApi
  class Client
    def self.connection
      @connection ||= build_connection
    end

    def self.build_connection
      config = Rails.application.config.external_todo_api
      Faraday.new(
        url: config[:base_url],
        request: { timeout: config[:timeout] }
      ) do |conn|
        conn.request :retry,
          max: config[:retries],
          methods: %i[get delete patch put head],
          retry_statuses: [429, 500, 502, 503, 504]
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
      end
    end

    def initialize(connection: self.class.connection)
      @connection = connection
    end

    def perform_request(method, path, payload = nil)
      response = @connection.public_send(method, path) do |req|
        if payload
          req.headers["Content-Type"] = "application/json"
          req.body = payload.to_json
        end
      end
      handle_response!(response)
      response.body
    end

    private

    def handle_response!(response)
      return if response.success?

      url = response.env.url.to_s
      status = response.status
      body = response.body.to_s[0, 500]
      log_level = status >= 500 ? :error : :warn

      Rails.logger.public_send(log_level, "[ExternalTodoApi] HTTP #{status} — url=#{url} body=#{body}")

      raise NotFoundError.new("Not found", status:, body:, url:) if status == 404
      raise ServerError.new("Server error", status:, body:, url:) if status >= 500
      raise ClientError.new("Request failed", status:, body:, url:)
    end
  end
end
