require "rails_helper"

RSpec.describe UnsplashClient do
  subject(:client) { described_class.new }

  describe "#search" do
    it "returns Unsplash photos with total_pages" do
      stub_unsplash_search
      result = client.search(query: "mountains", page: 1, per_page: 24)

      expect(result.total_pages).to eq(3)
      expect(result.map(&:id)).to eq(%w[Bkci_8qcdvQ 8mikJ83LmSQ])
    end

    it "maps a rate-limit 403 to RateLimited" do
      # Unsplash sends this 403 as text/plain, not JSON.
      stub_unsplash_search(status: 403, body: "Rate Limit Exceeded", headers: { "Content-Type" => "text/plain" })
      expect { client.search(query: "x", page: 1, per_page: 1) }.to raise_error(described_class::RateLimited)
    end

    it "maps other 403s to Unavailable" do
      stub_unsplash_search(status: 403, body: { errors: [ "Forbidden" ] }.to_json)
      expect { client.search(query: "x", page: 1, per_page: 1) }.to raise_error(described_class::Unavailable)
    end

    it "maps network failures to Unavailable" do
      stub_request(:get, UnsplashHelpers::UNSPLASH_SEARCH_URL).to_raise(Errno::ECONNREFUSED)
      expect { client.search(query: "x", page: 1, per_page: 1) }.to raise_error(described_class::Unavailable)
    end

    it "maps a non-JSON success body to Unavailable" do
      stub_unsplash_search(body: "<html>oops</html>")
      expect { client.search(query: "x", page: 1, per_page: 1) }.to raise_error(described_class::Unavailable)
    end

    it "never puts the access key in error messages" do
      stub_unsplash_search(status: 500, body: { errors: [ "Internal error" ] }.to_json)

      expect { client.search(query: "x", page: 1, per_page: 1) }
        .to raise_error(described_class::Unavailable) { |e| expect(e.message).not_to include(UnsplashHelpers::UNSPLASH_TEST_ACCESS_KEY) }
    end
  end

  describe "#track_download" do
    let(:location) { "https://api.unsplash.com/photos/Bkci_8qcdvQ/download?ixid=mock-ixid-1" }

    it "GETs the download location, keeping its ixid" do
      stub = stub_request(:get, %r{\Ahttps://api\.unsplash\.com/photos/Bkci_8qcdvQ/download})
        .with(query: hash_including("ixid" => "mock-ixid-1"))
        .to_return(status: 200, body: { url: "https://images.unsplash.com/photo-1" }.to_json)

      client.track_download(location)
      expect(stub).to have_been_requested
    end

    it "refuses to send the key anywhere but the Unsplash download endpoint" do
      [
        "https://evil.example.com/photos/abc/download",
        "http://api.unsplash.com/photos/abc/download",
        "https://api.unsplash.com/me",
        "not a url"
      ].each do |url|
        expect { client.track_download(url) }.to raise_error(described_class::Unavailable)
      end
      expect(WebMock).not_to have_requested(:any, /.*/)
    end
  end
end
