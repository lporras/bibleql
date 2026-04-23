require "rails_helper"

RSpec.describe "Admin::ApiKeyRequests", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, email: "admin@example.com", password: "password") }

  before { sign_in admin }

  describe "PUT /admin/api_key_requests/:id/resend_approval" do
    context "when the request is rejected" do
      let(:api_key_request) { create(:api_key_request, status: "rejected") }

      it "approves the request and creates an API key" do
        expect {
          put resend_approval_admin_api_key_request_path(api_key_request)
        }.to change(ApiKey, :count).by(1)

        expect(api_key_request.reload.status).to eq("approved")
      end

      it "sends the approval email to the requester" do
        expect {
          put resend_approval_admin_api_key_request_path(api_key_request)
        }.to change { ActionMailer::Base.deliveries.count }.by(1)

        email = ActionMailer::Base.deliveries.last
        expect(email.to).to eq([ api_key_request.email ])
        expect(email.subject).to eq("Your BibleQL API Key is Ready")
      end

      it "redirects to the request page with a notice" do
        put resend_approval_admin_api_key_request_path(api_key_request)

        expect(response).to redirect_to(admin_api_key_request_path(api_key_request))
        expect(flash[:notice]).to include(api_key_request.email)
      end
    end
  end
end
