require "rails_helper"

RSpec.describe "GraphQL trackImageDownload mutation", :with_cache, type: :request do
  include ActiveJob::TestHelper

  let(:headers) { auth_headers(create(:api_key, :installation).token) }

  def track(image_id, request_headers: headers)
    post "/graphql", params: { query: %(mutation { trackImageDownload(input: {imageId: "#{image_id}"}) { queued } }) },
      headers: request_headers
    JSON.parse(response.body)
  end

  it "queues a ping to the download_location returned by the earlier search (keeping its ixid)" do
    stub_unsplash_search
    BackgroundImageSearch.new(query: "mountains").call
    location = Rails.cache.read(BackgroundImageSearch.download_location_cache_key("Bkci_8qcdvQ"))
    expect(location).to include("ixid=mock-ixid-1")

    expect { track("Bkci_8qcdvQ") }.to have_enqueued_job(TrackUnsplashDownloadJob).with(location)
    expect(JSON.parse(response.body).dig("data", "trackImageDownload", "queued")).to be(true)
  end

  it "falls back to the canonical download endpoint when the photo is not cached" do
    expect { track("abc123") }
      .to have_enqueued_job(TrackUnsplashDownloadJob).with("https://api.unsplash.com/photos/abc123/download")
  end

  it "rejects ids that are not Unsplash photo ids" do
    body = nil
    expect { body = track("../../users/me") }.not_to have_enqueued_job
    expect(body.dig("errors", 0, "extensions", "code")).to eq("INVALID_INPUT")
  end

  it "is not available to developer keys" do
    body = nil
    expect { body = track("abc123", request_headers: auth_headers(create_test_api_key.token)) }.not_to have_enqueued_job
    expect(body["errors"].first["message"]).to include("Field 'trackImageDownload' doesn't exist on type 'Mutation'")
  end

  it "requires an API key" do
    expect { track("abc123", request_headers: {}) }.not_to have_enqueued_job
    expect(response).to have_http_status(:unauthorized)
  end
end
