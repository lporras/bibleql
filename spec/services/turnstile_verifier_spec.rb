require "rails_helper"

RSpec.describe TurnstileVerifier do
  let(:verify_url) { "https://challenges.cloudflare.com/turnstile/v0/siteverify" }
  let(:action) { TurnstileVerifier::API_KEY_REQUEST_ACTION }
  let(:success_body) { { success: true, action: action, hostname: "bibleql.org" } }

  around do |example|
    keys = %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY TURNSTILE_HOSTNAMES APP_HOST]
    original = ENV.to_h.slice(*keys)
    ENV["TURNSTILE_SITE_KEY"] = "site-key"
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key"
    ENV["TURNSTILE_HOSTNAMES"] = "bibleql.org, www.bibleql.org"
    ENV["APP_HOST"] = nil
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

  describe ".allowed_hostnames" do
    it "reads TURNSTILE_HOSTNAMES" do
      expect(described_class.allowed_hostnames).to eq(%w[bibleql.org www.bibleql.org])
    end

    it "falls back to APP_HOST" do
      ENV["TURNSTILE_HOSTNAMES"] = nil
      ENV["APP_HOST"] = "bibleql.org,bibleql.onrender.com"
      expect(described_class.allowed_hostnames).to eq(%w[bibleql.org bibleql.onrender.com])
    end

    it "drops localhost in production" do
      ENV["TURNSTILE_HOSTNAMES"] = "localhost,127.0.0.1,bibleql.org"
      allow(Rails.env).to receive(:production?).and_return(true)
      expect(described_class.allowed_hostnames).to eq(%w[bibleql.org])
    end
  end

  describe "#verify" do
    it "returns true when Cloudflare reports success, sending the secret, token and IP" do
      stub = stub_request(:post, verify_url)
        .with(body: { secret: "secret-key", response: "token", remoteip: "203.0.113.7" })
        .to_return(body: success_body.to_json)

      expect(described_class.new.verify("token", action:, remote_ip: "203.0.113.7")).to be(true)
      expect(stub).to have_been_requested
    end

    it "returns false when Cloudflare reports failure" do
      stub_request(:post, verify_url)
        .to_return(body: { success: false, "error-codes" => [ "invalid-input-response" ] }.to_json)

      expect(described_class.new.verify("token", action:)).to be(false)
    end

    it "returns false when the action does not match" do
      stub_request(:post, verify_url).to_return(body: success_body.merge(action: "login").to_json)
      expect(described_class.new.verify("token", action:)).to be(false)
    end

    it "returns false when the hostname is not allowed" do
      stub_request(:post, verify_url).to_return(body: success_body.merge(hostname: "evil.example").to_json)
      expect(described_class.new.verify("token", action:)).to be(false)
    end

    it "returns false without calling Cloudflare when no hostnames are allowed" do
      ENV["TURNSTILE_HOSTNAMES"] = nil
      expect(described_class.new.verify("token", action:)).to be(false)
      expect(a_request(:post, verify_url)).not_to have_been_made
    end

    it "returns false without calling Cloudflare for a blank or oversized token" do
      expect(described_class.new.verify("", action:)).to be(false)
      expect(described_class.new.verify("a" * 2049, action:)).to be(false)
      expect(described_class.new.verify([ "token" ], action:)).to be(false)
      expect(a_request(:post, verify_url)).not_to have_been_made
    end

    it "fails closed on a non-OK HTTP status" do
      stub_request(:post, verify_url).to_return(status: 500, body: success_body.to_json)
      expect(described_class.new.verify("token", action:)).to be(false)
    end

    it "fails closed on a timeout" do
      stub_request(:post, verify_url).to_timeout
      expect(described_class.new.verify("token", action:)).to be(false)
    end

    it "fails closed on a non-JSON response" do
      stub_request(:post, verify_url).to_return(status: 200, body: "<html>oops</html>")
      expect(described_class.new.verify("token", action:)).to be(false)
    end
  end
end
