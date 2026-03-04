module Api
  class ApiController < ActionController::API
    include ActionController::MimeResponds
    include ApiRescuable
  end
end
