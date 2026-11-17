require "rails_helper"

RSpec.describe ApiKeyRequest, type: :model do
  describe "validations" do
    it "requires name, email, and description" do
      request = ApiKeyRequest.new
      expect(request).not_to be_valid
      expect(request.errors[:name]).to be_present
      expect(request.errors[:email]).to be_present
      expect(request.errors[:description]).to be_present
    end

    it "validates email format" do
      request = build(:api_key_request, email: "not-an-email")
      expect(request).not_to be_valid
      expect(request.errors[:email]).to be_present
    end

    it "prevents duplicate pending requests for same email+environment" do
      create(:api_key_request, email: "user@example.com", environment: "test")
      duplicate = build(:api_key_request, email: "user@example.com", environment: "test")
      expect(duplicate).not_to be_valid
    end

    # Earlier requests are dated past REQUEST_COOLDOWN so only the pending-duplicate rule applies.
    it "allows same email in different environments" do
      create(:api_key_request, email: "user@example.com", environment: "test", created_at: 2.days.ago)
      live_request = build(:api_key_request, email: "user@example.com", environment: "live")
      expect(live_request).to be_valid
    end

    it "allows new request after previous one was approved" do
      request = create(:api_key_request, email: "user@example.com", environment: "test", created_at: 2.days.ago)
      request.approve!
      new_request = build(:api_key_request, email: "user@example.com", environment: "live")
      expect(new_request).to be_valid
    end
  end

  describe "#approve!" do
    it "creates an API key and updates status" do
      request = create(:api_key_request)

      expect { request.approve! }.to change(ApiKey, :count).by(1)

      expect(request.reload.status).to eq("approved")
      expect(request.api_key).to be_present
    end

    it "returns the API key with a plaintext token" do
      request = create(:api_key_request)
      api_key = request.approve!
      expect(api_key.token).to start_with("bql_test_")
    end
  end

  describe "#reject!" do
    it "updates status and stores reason" do
      request = create(:api_key_request)
      request.reject!("Spam request")

      expect(request.reload.status).to eq("rejected")
      expect(request.rejection_reason).to eq("Spam request")
    end
  end

  describe "name length" do
    it "allows names up to #{ApiKeyRequest::NAME_MAX_LENGTH} characters" do
      expect(build(:api_key_request, name: "a" * ApiKeyRequest::NAME_MAX_LENGTH)).to be_valid
    end

    it "rejects longer names on create" do
      request = build(:api_key_request, name: "a" * (ApiKeyRequest::NAME_MAX_LENGTH + 1))
      expect(request).not_to be_valid
      expect(request.errors[:name]).to include("is too long (maximum is 100 characters)")
    end

    it "still lets an existing request with a long name be rejected" do
      request = create(:api_key_request)
      request.update_column(:name, "a" * 300)

      expect { request.reject!("Spam") }.not_to raise_error
      expect(request.reload.status).to eq("rejected")
    end
  end

  describe ".normalize_email" do
    it "collapses spellings that reach the same inbox" do
      expect(described_class.normalize_email(" Victim+promo@Example.COM ")).to eq("victim@example.com")
      expect(described_class.normalize_email("j.o.h.n+1@gmail.com")).to eq("john@gmail.com")
      expect(described_class.normalize_email("j.o.h.n@googlemail.com")).to eq("john@googlemail.com")
    end

    it "keeps dots for non-Gmail domains" do
      expect(described_class.normalize_email("first.last@example.com")).to eq("first.last@example.com")
    end

    it "returns nil for blank or malformed input" do
      expect(described_class.normalize_email(nil)).to be_nil
      expect(described_class.normalize_email("no-at-sign")).to be_nil
    end
  end

  describe "one request per inbox per day" do
    it "stores the normalized email" do
      expect(create(:api_key_request, email: "John.Doe+x@Gmail.com").normalized_email).to eq("johndoe@gmail.com")
    end

    it "rejects another request for the same inbox within 24 hours, whatever its status" do
      create(:api_key_request, email: "victim@gmail.com", status: "rejected")

      request = build(:api_key_request, email: "V.ictim+2@gmail.com")
      expect(request).not_to be_valid
      expect(request.errors[:email]).to include("already requested a key recently. Please try again in 24 hours")
    end

    it "applies across environments" do
      create(:api_key_request, email: "dev@example.com", environment: "live", status: "approved")
      expect(build(:api_key_request, email: "dev@example.com", environment: "test")).not_to be_valid
    end

    it "allows a new request once the cooldown has passed" do
      create(:api_key_request, email: "dev@example.com", status: "rejected", created_at: 25.hours.ago)
      expect(build(:api_key_request, email: "dev@example.com")).to be_valid
    end

    it "does not block other inboxes" do
      create(:api_key_request, email: "dev@example.com")
      expect(build(:api_key_request, email: "other@example.com")).to be_valid
    end
  end
end
