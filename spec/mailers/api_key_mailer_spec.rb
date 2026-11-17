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

  # The form is public, so text a visitor typed must never reach an email: otherwise a bot can
  # use the form to send its own message from bibleql.org to any address.
  describe "visitor-supplied text" do
    let(:request) do
      create(:api_key_request, name: "Claim your prize at scam.example",
                               description: "Visit phish.example now")
    end

    it "is not included in the approval email" do
      api_key = request.approve!
      body = ApiKeyMailer.key_approved(request, api_key.token).body.encoded

      expect(body).not_to include("scam.example")
      expect(body).not_to include("phish.example")
    end

    it "is not included in the rejection email" do
      request.reject!("Spam request")
      body = ApiKeyMailer.key_rejected(request).body.encoded

      expect(body).not_to include("scam.example")
      expect(body).not_to include("phish.example")
    end
  end
end
