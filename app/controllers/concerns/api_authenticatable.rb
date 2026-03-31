module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    attr_reader :current_api_key
  end

  private

  def authenticate_api_key!
    token = extract_bearer_token
    @current_api_key = ApiKey.authenticate(token)

    if @current_api_key.nil?
      render json: { errors: [ { message: "Invalid or missing API key" } ] }, status: :unauthorized
      return
    end

    unless @current_api_key.environment == ApiKey.expected_environment
      @current_api_key = nil
      render json: { errors: [ { message: "API key not valid for this environment" } ] }, status: :unauthorized
    end
  end

  def extract_bearer_token
    header = request.headers["Authorization"]
    header&.match(/\ABearer\s+(.+)\z/)&.captures&.first
  end
end
