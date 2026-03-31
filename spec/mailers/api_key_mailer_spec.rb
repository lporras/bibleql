require "rails_helper"

RSpec.describe ApiKeyMailer, type: :mailer do
  describe "#key_approved" do
    it "sends an approval email with the token" do
      request = create(:api_key_request)
      api_key = request.approve!

      mail = ApiKeyMailer.key_approved(request, api_key.token)

      expect(mail.to).to eq([ request.email ])
      expect(mail.subject).to eq("Your BibleQL API Key is Ready")
      expect(mail.body.encoded).to include(api_key.token)
    end
  end

  describe "#key_rejected" do
    it "sends a rejection email with reason" do
      request = create(:api_key_request)
      request.reject!("Spam request")

      mail = ApiKeyMailer.key_rejected(request)

      expect(mail.to).to eq([ request.email ])
      expect(mail.subject).to eq("BibleQL API Key Request Update")
      expect(mail.body.encoded).to include("Spam request")
    end
  end
end
