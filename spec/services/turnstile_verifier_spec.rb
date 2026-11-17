require "rails_helper"

RSpec.describe TurnstileVerifier do
  let(:verify_url) { "https://challenges.cloudflare.com/turnstile/v0/siteverify" }

  around do |example|
    keys = %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY]
    original = ENV.to_h.slice(*keys)
    ENV["TURNSTILE_SITE_KEY"] = "site-key"
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key"
    example.run
  ensure
    keys.each { |key| ENV[key] = original[key] }
  end

  describe ".enabled?" do
    it "is true when both keys are set" do
      expect(described_class).to be_enabled
    end

    it "is false when either key is missing" do
      ENV["TURNSTILE_SECRET_KEY"] = ""
      expect(described_class).not_to be_enabled
    end
  end

  describe "#verify" do
    it "returns true when Cloudflare reports success, sending the secret, token and IP" do
      stub = stub_request(:post, verify_url)
        .with(body: { secret: "secret-key", response: "token", remoteip: "203.0.113.7" })
        .to_return(body: { success: true }.to_json)

      expect(described_class.new.verify("token", remote_ip: "203.0.113.7")).to be(true)
      expect(stub).to have_been_requested
    end

    it "returns false when Cloudflare reports failure" do
      stub_request(:post, verify_url)
        .to_return(body: { success: false, "error-codes" => [ "invalid-input-response" ] }.to_json)

      expect(described_class.new.verify("token")).to be(false)
    end

    it "returns false without calling Cloudflare for a blank token" do
      expect(described_class.new.verify("")).to be(false)
      expect(a_request(:post, verify_url)).not_to have_been_made
    end

    it "fails closed on a timeout" do
      stub_request(:post, verify_url).to_timeout
      expect(described_class.new.verify("token")).to be(false)
    end

    it "fails closed on a non-JSON response" do
      stub_request(:post, verify_url).to_return(status: 502, body: "<html>Bad gateway</html>")
      expect(described_class.new.verify("token")).to be(false)
    end
  end
end
