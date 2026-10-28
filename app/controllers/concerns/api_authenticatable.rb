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
      render_unauthenticated("Invalid or missing API key")
      return
    end

    unless @current_api_key.environment == ApiKey.expected_environment
      @current_api_key = nil
      render_unauthenticated("API key not valid for this environment")
    end
  end

  def render_unauthenticated(message)
    render json: { errors: [ { message: message, extensions: { code: "UNAUTHENTICATED" } } ] }, status: :unauthorized
  end

  def extract_bearer_token
    header = request.headers["Authorization"]
    header&.match(/\ABearer\s+(.+)\z/)&.captures&.first
  end
end
