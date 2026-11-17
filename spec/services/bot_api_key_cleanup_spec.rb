require "rails_helper"

RSpec.describe BotApiKeyCleanup do
  subject(:cleanup) { described_class.new }

  let(:casino_spam) do
    "* * * 🚀 FREE $3000 BONUS BALANCE: Get $3000 on your bonus account right after sign-up by " \
      "opening https://hacked-site.example/go.php?abc 🔑 * * *"
  end
  let(:seo_phrase) { "I would like more information. Please contact me by email — get a free bible api key." }

  def approved_request(**attrs)
    request = create(:api_key_request, status: "pending", **attrs)
    request.approve!
    request.reload
  end

  let!(:casino_request) { approved_request(name: casino_spam, description: "khmulx") }
  let!(:seo_request) { approved_request(name: "Hannah Thomas", description: seo_phrase) }
  let!(:used_bot_request) do
    approved_request(name: "Visit www.spam.example now", description: "x").tap do |r|
      r.api_key.update!(requests_count: 40)
    end
  end
  let!(:real_request) { approved_request(name: "Ana", description: "Bilingual Bible study shortcuts for iPhone") }
  let!(:rejected_spam) { create(:api_key_request, name: casino_spam, status: "rejected") }
  let!(:rejected_real) { create(:api_key_request, name: "Luis", status: "rejected") }
  let!(:pending_real) { create(:api_key_request, name: "Maria", description: "Church app") }
  let!(:installation_key) { create(:api_key, :installation) }

  describe "#preview" do
    it "counts what would be deleted without deleting anything" do
      expect {
        result = cleanup.preview
        expect(result.bot_requests).to eq(4)       # 3 approved bots + rejected casino spam
        expect(result.bot_keys).to eq(3)
        expect(result.rejected_requests).to eq(1)  # the non-spam rejected one
        expect(result.used_keys).to eq([ used_bot_request.api_key ])
      }.to change(ApiKey, :count).by(0).and change(ApiKeyRequest, :count).by(0)
    end
  end

  describe "#call" do
    it "deletes bot requests, their keys and every rejected request" do
      bot_key_ids = [ casino_request, seo_request, used_bot_request ].map(&:api_key_id)

      result = cleanup.call

      expect(result.bot_requests).to eq(4)
      expect(result.bot_keys).to eq(3)
      expect(result.rejected_requests).to eq(1)
      expect(ApiKey.where(id: bot_key_ids)).to be_empty
      expect(ApiKeyRequest.where(id: [ casino_request, seo_request, used_bot_request, rejected_spam, rejected_real ])).to be_empty
    end

    it "keeps real requests and keys, pending requests and installation keys" do
      cleanup.call

      expect(ApiKeyRequest.exists?(real_request.id)).to be(true)
      expect(ApiKey.exists?(real_request.api_key_id)).to be(true)
      expect(ApiKeyRequest.exists?(pending_real.id)).to be(true)
      expect(ApiKey.exists?(installation_key.id)).to be(true)
    end

    it "returns bot keys that had been used" do
      expect(cleanup.call.used_keys.map(&:token_prefix)).to eq([ used_bot_request.api_key.token_prefix ])
    end
  end
end
