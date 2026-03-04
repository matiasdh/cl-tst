module ApiRescuable
  extend ActiveSupport::Concern

  included do
    rescue_from ActionController::UnknownFormat, with: :unsupported_format
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  end

  private

  def unsupported_format
    render json: { error: "Not Acceptable", message: "This API only supports JSON format." }, status: :not_acceptable
  end

  def record_not_found(exception)
    model_name = exception.model || "Record"
    render json: { error: "#{model_name} not found" }, status: :not_found
  end

  def record_invalid(exception)
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end
end
