require "rails_helper"

RSpec.describe "GraphQL backgroundImages query", :with_cache, type: :request do
  let(:api_key) { create(:api_key, :installation) }
  let(:headers) { auth_headers(api_key.token) }
  let(:query) do
    <<~GQL
      query Search($q: String!, $page: Int, $perPage: Int) {
        backgroundImages(query: $q, page: $page, perPage: $perPage) {
          page totalPages hasMore errorCode
          images {
            id width height color blurHash altDescription
            urls { raw full regular small thumb }
            photographer { name username profileUrl }
            unsplashUrl downloadLocation
          }
        }
      }
    GQL
  end

  def search(q = "sunrise", page: nil, per_page: nil, request_headers: headers)
    variables = { q: q, page: page, perPage: per_page }.compact
    post "/graphql", params: { query: query, variables: variables }.to_json,
      headers: request_headers.merge("Content-Type" => "application/json")
    JSON.parse(response.body)
  end

  def result(body)
    body.dig("data", "backgroundImages")
  end

  it "requires an API key and never calls Unsplash without one" do
    stub = stub_unsplash_search
    search(request_headers: {})

    expect(response).to have_http_status(:unauthorized)
    expect(stub).not_to have_been_requested
  end

  it "is not part of the schema for developer keys (only BibleQL client installations)" do
    stub = stub_unsplash_search
    body = search(request_headers: auth_headers(create_test_api_key.token))

    expect(body["errors"].first["message"]).to include("Field 'backgroundImages' doesn't exist on type 'Query'")
    expect(body["data"]).to be_nil
    expect(stub).not_to have_been_requested
  end

  it "is hidden from introspection for developer keys and shown to installation keys" do
    introspect = ->(token) {
      post "/graphql", params: { query: "{ __type(name: \"Query\") { fields { name } } }" }, headers: auth_headers(token)
      JSON.parse(response.body).dig("data", "__type", "fields").map { |f| f["name"] }
    }

    expect(introspect.(create_test_api_key.token)).not_to include("backgroundImages")
    expect(introspect.(api_key.token)).to include("backgroundImages")
  end

  it "proxies the search with the server's Client-ID, high content filter and utm_source" do
    stub = stub_unsplash_search
    search("sunrise", page: 2, per_page: 10)

    expect(stub.with(
      query: hash_including("query" => "sunrise", "page" => "2", "per_page" => "10", "content_filter" => "high",
        "utm_source" => "bibleql-reader"),
      headers: { "Authorization" => "Client-ID #{UnsplashHelpers::UNSPLASH_TEST_ACCESS_KEY}" }
    )).to have_been_requested.once
  end

  it "maps photos, hotlinking Unsplash CDN URLs and UTM-tagging attribution links" do
    stub_unsplash_search
    data = result(search)
    image = data["images"].first

    expect(data).to include("page" => 1, "totalPages" => 3, "hasMore" => true, "errorCode" => nil)
    expect(data["images"].size).to eq(2)
    expect(image).to include(
      "id" => "Bkci_8qcdvQ", "width" => 5760, "height" => 3840, "color" => "#264040",
      "blurHash" => "LGF5]+Yk^6#M@-5c,1J5@[or[Q6.", "altDescription" => "green mountain valley under cloudy sky"
    )
    expect(image["urls"]["regular"]).to start_with("https://images.unsplash.com/photo-1464822759023-fed622ff2c3b")
    expect(image["photographer"]).to include("name" => "Kalen Emsley", "username" => "kalenemsley")

    [ image["photographer"]["profileUrl"], image["unsplashUrl"] ].each do |link|
      params = Rack::Utils.parse_query(URI.parse(link).query)
      expect(params).to include("utm_source" => "bibleql-reader", "utm_medium" => "referral")
    end
    expect(image["photographer"]["profileUrl"]).to start_with("https://unsplash.com/@kalenemsley?")
    expect(image["downloadLocation"]).to include("ixid=mock-ixid-1")
  end

  it "never includes the Unsplash access key in the response" do
    stub_unsplash_search
    search

    expect(response.body).not_to include(UnsplashHelpers::UNSPLASH_TEST_ACCESS_KEY)
  end

  it "serves a repeated (normalized) query from cache without calling Unsplash again" do
    stub = stub_unsplash_search

    first = result(search("Sunrise"))
    second = result(search("  sunrise  "))

    expect(stub).to have_been_requested.once
    expect(second).to eq(first)
  end

  it "caches each page separately" do
    stub = stub_unsplash_search
    search("sunrise", page: 1)
    search("sunrise", page: 2)

    expect(stub).to have_been_requested.twice
  end

  it "clamps perPage to Unsplash's maximum of 30" do
    stub = stub_unsplash_search
    search("sunrise", per_page: 500)

    expect(stub.with(query: hash_including("per_page" => "30"))).to have_been_requested
  end

  it "returns RATE_LIMITED with no images (not an error) when Unsplash's quota is exhausted, then backs off" do
    stub = stub_unsplash_search(status: 403, body: "Rate Limit Exceeded",
      headers: { "Content-Type" => "text/plain", "X-Ratelimit-Remaining" => "0" })

    body = search("sunrise")
    expect(response).to have_http_status(:ok)
    expect(body["errors"]).to be_nil
    expect(result(body)).to include("images" => [], "errorCode" => "RATE_LIMITED", "hasMore" => false)

    expect(result(search("mountains"))["errorCode"]).to eq("RATE_LIMITED")
    expect(stub).to have_been_requested.once
  end

  it "does not cache failures" do
    stub_request(:get, UnsplashHelpers::UNSPLASH_SEARCH_URL)
      .to_return({ status: 500, body: { errors: [ "boom" ] }.to_json }, { status: 200, body: unsplash_search_body })

    expect(result(search)["errorCode"]).to eq("UNAVAILABLE")
    expect(result(search)["images"].size).to eq(2)
  end

  it "returns UNAVAILABLE on a timeout" do
    stub_request(:get, UnsplashHelpers::UNSPLASH_SEARCH_URL).to_timeout

    expect(result(search)).to include("images" => [], "errorCode" => "UNAVAILABLE")
  end

  it "returns NOT_CONFIGURED when Unsplash rejects the key" do
    stub_unsplash_search(status: 401, body: { errors: [ "OAuth error: The access token is invalid" ] }.to_json)

    expect(result(search)["errorCode"]).to eq("NOT_CONFIGURED")
  end

  it "returns NOT_CONFIGURED without calling Unsplash when no key is configured" do
    Unsplash.configuration.application_access_key = nil
    stub = stub_unsplash_search

    expect(result(search)["errorCode"]).to eq("NOT_CONFIGURED")
    expect(stub).not_to have_been_requested
  end

  it "rejects a blank query" do
    body = search("   ")
    expect(body.dig("errors", 0, "extensions", "code")).to eq("INVALID_INPUT")
  end
end
