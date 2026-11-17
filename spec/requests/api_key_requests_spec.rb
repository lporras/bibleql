require "rails_helper"

RSpec.describe "API Key Requests", type: :request do
  # .env is loaded in test too, so pin the flag for every example.
  around do |example|
    original = ENV["API_KEY_REQUESTS_PAUSED"]
    ENV["API_KEY_REQUESTS_PAUSED"] = paused
    example.run
  ensure
    ENV["API_KEY_REQUESTS_PAUSED"] = original
  end

  let(:paused) { nil }

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

    it "creates a new request and auto-approves it" do
      expect {
        post api_key_requests_path, params: valid_params
      }.to change(ApiKeyRequest, :count).by(1)
        .and change(ApiKey, :count).by(1)

      expect(response).to redirect_to(success_api_key_requests_path(email: "john@example.com"))
      expect(ApiKeyRequest.last.status).to eq("approved")
    end

    it "sends the approval email with the API key" do
      expect {
        post api_key_requests_path, params: valid_params
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      email = ActionMailer::Base.deliveries.last
      expect(email.to).to eq([ "john@example.com" ])
      expect(email.subject).to eq("Your BibleQL API Key is Ready")
    end

    it "rejects the request and rolls back the API key if email delivery fails" do
      allow(ApiKeyMailer).to receive_message_chain(:key_approved, :deliver_now).and_raise(StandardError, "SMTP error")

      expect {
        post api_key_requests_path, params: valid_params
      }.to change(ApiKeyRequest, :count).by(1)
        .and change(ApiKey, :count).by(0)

      expect(response).to redirect_to(success_api_key_requests_path(email: "john@example.com"))
      request = ApiKeyRequest.last
      expect(request.status).to eq("rejected")
      expect(request.rejection_reason).to eq("Auto-approval failed: email delivery error")
    end

    it "returns unprocessable_content with invalid params" do
      post api_key_requests_path, params: { api_key_request: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "prevents duplicate pending requests" do
      create(:api_key_request, email: "john@example.com", environment: "test")

      expect {
        post api_key_requests_path, params: valid_params
      }.not_to change(ApiKeyRequest, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context "when requests are paused" do
    let(:paused) { "true" }

    it "shows a notice instead of the form" do
      get new_api_key_request_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("temporarily paused")
      expect(response.body).not_to include("Submit Request")
    end

    it "refuses submissions without creating records or sending email" do
      expect {
        post api_key_requests_path, params: {
          api_key_request: { name: "Bot", email: "bot@example.com", description: "spam" }
        }
      }.to change(ApiKeyRequest, :count).by(0)
        .and change(ApiKey, :count).by(0)
        .and change { ActionMailer::Base.deliveries.count }.by(0)

      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
