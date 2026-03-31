module ApiHelpers
  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def create_test_api_key
    create(:api_key, environment: "test")
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
