require "rails_helper"

RSpec.describe "Rate limiting", :with_cache, type: :request do
  let(:query) { "{ books { bookId } }" }

  def error_code
    JSON.parse(response.body).dig("errors", 0, "extensions", "code")
  end

  describe "registration throttle (Rack::Attack)" do
    around do |example|
      Rack::Attack.enabled = true
      example.run
    ensure
      Rack::Attack.enabled = false
    end

    def register
      post "/graphql", params: {
        query: %(mutation { registerInstallation(input: {installationId: "#{SecureRandom.uuid}", platform: LINUX, appVersion: "1.0.0"}) { token } })
      }
    end

    it "allows 10 unauthenticated requests per hour per IP, then returns RATE_LIMITED" do
      10.times do
        register
        expect(response).to have_http_status(:ok)
      end

      register
      expect(response).to have_http_status(:too_many_requests)
      expect(error_code).to eq("RATE_LIMITED")
      expect(response.headers["Retry-After"]).to be_present
      expect(Installation.count).to eq(10)
    end

    it "does not count authenticated requests against the registration limit" do
      api_key = create_test_api_key
      11.times { post "/graphql", params: { query: query }, headers: auth_headers(api_key.token) }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "per-key daily limit" do
    it "gives installation keys the same default as developer keys" do
      expect(create(:api_key, :installation).daily_limit).to eq(1000)
      expect(create_test_api_key.daily_limit).to eq(1000)
    end

    it "limits installation keys to their daily limit" do
      api_key = create(:api_key, :installation, daily_limit: 3)

      3.times do
        post "/graphql", params: { query: query }, headers: auth_headers(api_key.token)
        expect(response).to have_http_status(:ok)
      end

      post "/graphql", params: { query: query }, headers: auth_headers(api_key.token)
      expect(response).to have_http_status(:too_many_requests)
      expect(error_code).to eq("RATE_LIMITED")
      expect(JSON.parse(response.body).dig("errors", 0, "extensions", "retryAfter")).to be_positive
      expect(api_key.reload.requests_count).to eq(3)
    end

    it "keeps separate quotas per key" do
      limited = create(:api_key, :installation, daily_limit: 1)
      other = create(:api_key, :installation, daily_limit: 1)

      2.times { post "/graphql", params: { query: query }, headers: auth_headers(limited.token) }
      expect(response).to have_http_status(:too_many_requests)

      post "/graphql", params: { query: query }, headers: auth_headers(other.token)
      expect(response).to have_http_status(:ok)
    end

    it "resets the next UTC day" do
      api_key = create(:api_key, :installation, daily_limit: 1)

      travel_to Time.utc(2026, 10, 27, 23, 0) do
        2.times { post "/graphql", params: { query: query }, headers: auth_headers(api_key.token) }
        expect(response).to have_http_status(:too_many_requests)
      end

      travel_to Time.utc(2026, 10, 28, 0, 5) do
        post "/graphql", params: { query: query }, headers: auth_headers(api_key.token)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
