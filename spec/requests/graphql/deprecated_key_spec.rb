require "rails_helper"

RSpec.describe "Deprecated API keys", type: :request do
  let(:query) { "{ books { bookId } }" }

  it "still serves data and adds an updateRequired extension" do
    create(:book, book_id: "GEN", name: "Genesis", testament: "OT", position: 1)
    api_key = create(:api_key, :deprecated)

    post "/graphql", params: { query: query }, headers: auth_headers(api_key.token)

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(body.dig("data", "books", 0, "bookId")).to eq("GEN")
    expect(body["extensions"]).to include(
      "updateRequired" => true,
      "message" => GraphqlController::DEFAULT_UPDATE_MESSAGE,
      "updateUrl" => GraphqlController::DEFAULT_UPDATE_URL
    )
  end

  it "uses DEPRECATED_KEY_MESSAGE and READER_UPDATE_URL when set" do
    api_key = create(:api_key, :deprecated)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("DEPRECATED_KEY_MESSAGE").and_return("Please update BibleQL Reader")
    allow(ENV).to receive(:[]).with("READER_UPDATE_URL").and_return("https://example.com/download")

    post "/graphql", params: { query: query }, headers: auth_headers(api_key.token)

    expect(JSON.parse(response.body)["extensions"]).to include(
      "message" => "Please update BibleQL Reader", "updateUrl" => "https://example.com/download"
    )
  end

  it "adds no extension for keys that are not deprecated" do
    post "/graphql", params: { query: query }, headers: auth_headers(create_test_api_key.token)

    expect(JSON.parse(response.body)).not_to have_key("extensions")
  end

  it "logs each use so remaining traffic can be watched" do
    api_key = create(:api_key, :deprecated)
    allow(Rails.logger).to receive(:info).and_call_original

    post "/graphql", params: { query: query }, headers: auth_headers(api_key.token)

    expect(Rails.logger).to have_received(:info).with(a_string_including("[deprecated_api_key] prefix=#{api_key.token_prefix}"))
  end

  it "keeps the same daily limit as any other key" do
    expect(create(:api_key, :deprecated).daily_limit).to eq(create_test_api_key.daily_limit)
  end
end
