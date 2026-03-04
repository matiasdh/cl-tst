# Shared rescue handlers for web (HTML/Turbo Stream) controllers.
# Controllers can override handle_record_invalid to customize RecordInvalid responses.
module Rescuable
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  end

  private

  def record_not_found(_exception)
    redirect_to todo_lists_path, alert: 'Record not found.'
  end

  def record_invalid(exception)
    if respond_to?(:handle_record_invalid, true)
      handle_record_invalid(exception)
    else
      default_record_invalid(exception)
    end
  end

  def default_record_invalid(_exception)
    redirect_back fallback_location: todo_lists_path, alert: 'Could not save. Please try again.'
  end
end
