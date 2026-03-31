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

    it "allows same email in different environments" do
      create(:api_key_request, email: "user@example.com", environment: "test")
      live_request = build(:api_key_request, email: "user@example.com", environment: "live")
      expect(live_request).to be_valid
    end

    it "allows new request after previous one was approved" do
      request = create(:api_key_request, email: "user@example.com", environment: "test")
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
end
