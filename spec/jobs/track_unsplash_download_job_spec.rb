require "rails_helper"

RSpec.describe TrackUnsplashDownloadJob do
  let(:location) { "https://api.unsplash.com/photos/abc123/download?ixid=xyz" }

  it "pings the download location" do
    stub = stub_request(:get, %r{\Ahttps://api\.unsplash\.com/photos/abc123/download})
      .to_return(status: 200, body: { url: "https://images.unsplash.com/x" }.to_json)

    described_class.perform_now(location)
    expect(stub).to have_been_requested
  end

  it "logs and discards Unsplash failures instead of retrying" do
    stub_request(:get, %r{\Ahttps://api\.unsplash\.com/photos/abc123/download}).to_return(status: 500, body: "{}")
    allow(Rails.logger).to receive(:warn).and_call_original

    expect { described_class.perform_now(location) }.not_to raise_error
    expect(Rails.logger).to have_received(:warn).with(a_string_including("[unsplash] download tracking failed"))
  end
end
