require "rails_helper"

RSpec.describe "GraphQL Authentication", type: :request do
  let(:query) { "{ translations { identifier } }" }

  describe "POST /graphql" do
    it "returns 401 when no Authorization header is present" do
      post "/graphql", params: { query: query }
      expect(response).to have_http_status(:unauthorized)

      body = JSON.parse(response.body)
      expect(body["errors"].first["message"]).to eq("Invalid or missing API key")
    end

    it "returns 401 when token is invalid" do
      post "/graphql", params: { query: query }, headers: auth_headers("bql_test_invalid")
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when token belongs to a revoked key" do
      api_key = create_test_api_key
      token = api_key.token
      api_key.revoke!

      post "/graphql", params: { query: query }, headers: auth_headers(token)
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when using a live key in test environment" do
      api_key = create(:api_key, environment: "live")
      post "/graphql", params: { query: query }, headers: auth_headers(api_key.token)
      expect(response).to have_http_status(:unauthorized)

      body = JSON.parse(response.body)
      expect(body["errors"].first["message"]).to eq("API key not valid for this environment")
    end

    it "returns 200 with a valid test key" do
      api_key = create_test_api_key
      post "/graphql", params: { query: query }, headers: auth_headers(api_key.token)
      expect(response).to have_http_status(:ok)
    end

    it "increments usage counter after successful request" do
      api_key = create_test_api_key
      token = api_key.token

      expect {
        post "/graphql", params: { query: query }, headers: auth_headers(token)
      }.to change { api_key.reload.requests_count }.by(1)
    end

    it "updates last_used_at after successful request" do
      api_key = create_test_api_key
      token = api_key.token

      post "/graphql", params: { query: query }, headers: auth_headers(token)
      expect(api_key.reload.last_used_at).to be_present
    end
  end
end
