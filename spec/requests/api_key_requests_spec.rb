require "rails_helper"

RSpec.describe "API Key Requests", type: :request do
  describe "GET /api-keys/request" do
    it "renders the request form" do
      get new_api_key_request_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api-keys/request" do
    let(:valid_params) do
      {
        api_key_request: {
          name: "John Doe",
          email: "john@example.com",
          description: "Building a Bible study app",
          environment: "test"
        }
      }
    end

    it "creates a new request with valid params" do
      expect {
        post api_key_requests_path, params: valid_params
      }.to change(ApiKeyRequest, :count).by(1)

      expect(response).to redirect_to(success_api_key_requests_path(email: "john@example.com"))
    end

    it "returns unprocessable_entity with invalid params" do
      post api_key_requests_path, params: { api_key_request: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents duplicate pending requests" do
      create(:api_key_request, email: "john@example.com", environment: "test")

      expect {
        post api_key_requests_path, params: valid_params
      }.not_to change(ApiKeyRequest, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
