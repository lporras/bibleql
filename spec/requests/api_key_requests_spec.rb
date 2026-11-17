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

  # .env is loaded in test too; keep Turnstile off unless an example turns it on.
  before { allow(TurnstileVerifier).to receive(:enabled?).and_return(false) }

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

  describe "Turnstile" do
    let(:verifier) { instance_double(TurnstileVerifier) }
    let(:valid_params) do
      { api_key_request: { name: "Jane", email: "jane@example.com", description: "A study app" } }
    end

    before do
      allow(TurnstileVerifier).to receive_messages(enabled?: true, site_key: "site-key-123")
      allow(TurnstileVerifier).to receive(:new).and_return(verifier)
    end

    it "renders the widget on the form" do
      get new_api_key_request_path
      expect(response.body).to include('data-controller="turnstile"')
      expect(response.body).to include("site-key-123")
    end

    it "creates the request when the token verifies, passing the real client IP" do
      allow(verifier).to receive(:verify).with("good-token", remote_ip: "203.0.113.7").and_return(true)

      expect {
        post api_key_requests_path,
          params: valid_params.merge("cf-turnstile-response" => "good-token"),
          headers: { "REMOTE_ADDR" => "172.71.151.144", "CF-Connecting-IP" => "203.0.113.7" }
      }.to change(ApiKeyRequest, :count).by(1)

      expect(response).to redirect_to(success_api_key_requests_path(email: "jane@example.com"))
    end

    it "refuses the request without saving or emailing when the token fails" do
      allow(verifier).to receive(:verify).and_return(false)

      expect {
        post api_key_requests_path, params: valid_params.merge("cf-turnstile-response" => "bad")
      }.to change(ApiKeyRequest, :count).by(0)
        .and change(ApiKey, :count).by(0)
        .and change { ActionMailer::Base.deliveries.count }.by(0)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Please complete the verification challenge")
    end
  end

  describe "spam check" do
    let(:spam_params) do
      { api_key_request: { name: "Get $3000 bonus at https://casino.example/go.php", email: "victim@example.com",
                           description: "khmulx" } }
    end

    it "silently rejects a flagged request: same redirect, no key, no email" do
      expect {
        post api_key_requests_path, params: spam_params
      }.to change(ApiKeyRequest, :count).by(1)
        .and change(ApiKey, :count).by(0)
        .and change { ActionMailer::Base.deliveries.count }.by(0)

      expect(response).to redirect_to(success_api_key_requests_path(email: "victim@example.com"))
      request = ApiKeyRequest.last
      expect(request.status).to eq("rejected")
      expect(request.rejection_reason).to eq("Flagged as spam: link in name")
    end

    it "silently rejects a request that filled the honeypot" do
      params = { api_key_request: { name: "Jane", email: "jane@example.com", description: "Study app" },
                 website: "anything" }

      expect { post api_key_requests_path, params: params }
        .to change { ActionMailer::Base.deliveries.count }.by(0)

      expect(response).to redirect_to(success_api_key_requests_path(email: "jane@example.com"))
      expect(ApiKeyRequest.last.rejection_reason).to eq("Flagged as spam: honeypot filled")
    end

    it "shows a form error for an overlong name, without saving or emailing" do
      params = { api_key_request: { name: "a" * 101, email: "jane@example.com", description: "Study app" } }

      expect { post api_key_requests_path, params: params }
        .to change(ApiKeyRequest, :count).by(0)
        .and change { ActionMailer::Base.deliveries.count }.by(0)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Name is too long")
    end

    it "renders the honeypot field on the form" do
      get new_api_key_request_path
      expect(response.body).to include('name="website"')
    end
  end

  describe "per-inbox limit" do
    it "refuses a second request for the same inbox and sends only one email" do
      post api_key_requests_path, params: { api_key_request: { name: "A", email: "victim@gmail.com", description: "x" } }

      expect {
        post api_key_requests_path, params: { api_key_request: { name: "A", email: "Vic.tim+2@gmail.com", description: "x" } }
      }.to change(ApiKeyRequest, :count).by(0)
        .and change { ActionMailer::Base.deliveries.count }.by(0)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Please try again in 24 hours")
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
