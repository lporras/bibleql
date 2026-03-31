require "rails_helper"

RSpec.describe ApiKey, type: :model do
  describe "creation" do
    it "generates a token with the correct prefix" do
      key = create(:api_key, environment: "test")
      expect(key.token).to start_with("bql_test_")
    end

    it "generates a live token prefix" do
      key = create(:api_key, environment: "live")
      expect(key.token).to start_with("bql_live_")
    end

    it "stores the token digest" do
      key = create(:api_key)
      expect(key.token_digest).to be_present
      expect(BCrypt::Password.new(key.token_digest)).to eq(key.token)
    end

    it "stores the first 12 characters as token_prefix" do
      key = create(:api_key)
      expect(key.token_prefix).to eq(key.token[0, 12])
    end

    it "does not persist the plaintext token" do
      key = create(:api_key)
      reloaded = ApiKey.find(key.id)
      expect(reloaded.token).to be_nil
    end
  end

  describe "validations" do
    it "requires a name" do
      key = build(:api_key, name: nil)
      expect(key).not_to be_valid
    end

    it "requires an email" do
      key = build(:api_key, email: nil)
      expect(key).not_to be_valid
    end

    it "enforces one key per email per environment" do
      create(:api_key, email: "user@example.com", environment: "test")
      duplicate = build(:api_key, email: "user@example.com", environment: "test")
      expect(duplicate).not_to be_valid
    end

    it "allows same email in different environments" do
      create(:api_key, email: "user@example.com", environment: "test")
      live_key = build(:api_key, email: "user@example.com", environment: "live")
      expect(live_key).to be_valid
    end

    it "validates environment inclusion" do
      key = build(:api_key, environment: "staging")
      expect(key).not_to be_valid
    end
  end

  describe ".authenticate" do
    it "returns the key for a valid token" do
      key = create(:api_key)
      result = ApiKey.authenticate(key.token)
      expect(result).to eq(key)
    end

    it "returns nil for an invalid token" do
      expect(ApiKey.authenticate("bql_test_invalid_token")).to be_nil
    end

    it "returns nil for a blank token" do
      expect(ApiKey.authenticate("")).to be_nil
      expect(ApiKey.authenticate(nil)).to be_nil
    end

    it "returns nil for a revoked key" do
      key = create(:api_key)
      token = key.token
      key.revoke!
      expect(ApiKey.authenticate(token)).to be_nil
    end
  end

  describe "#regenerate!" do
    it "revokes the old key and creates a new one" do
      old_key = create(:api_key, email: "user@example.com", environment: "test")
      old_token = old_key.token

      new_key = old_key.regenerate!

      expect(old_key.reload).to be_revoked
      expect(new_key).to be_persisted
      expect(new_key).not_to be_revoked
      expect(new_key.email).to eq("user@example.com")
      expect(new_key.environment).to eq("test")
      expect(new_key.token).to be_present
      expect(new_key.token).not_to eq(old_token)
      expect(ApiKey.authenticate(old_token)).to be_nil
      expect(ApiKey.authenticate(new_key.token)).to eq(new_key)
    end
  end

  describe "#revoke!" do
    it "sets revoked_at" do
      key = create(:api_key)
      key.revoke!
      expect(key.revoked_at).to be_present
      expect(key).to be_revoked
    end
  end

  describe "#track_usage!" do
    it "increments requests_count and updates last_used_at" do
      key = create(:api_key)
      expect { key.track_usage! }.to change { key.reload.requests_count }.by(1)
      expect(key.last_used_at).to be_present
    end
  end

  describe ".expected_environment" do
    it "returns test for non-production environments" do
      expect(ApiKey.expected_environment).to eq("test")
    end
  end
end
