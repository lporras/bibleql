require "rails_helper"

RSpec.describe "GraphQL registerInstallation mutation", type: :request do
  let(:installation_id) { SecureRandom.uuid }
  let(:mutation) do
    <<~GQL
      mutation Register($input: RegisterInstallationInput!) {
        registerInstallation(input: $input) { token installationId dailyLimit }
      }
    GQL
  end

  def register(id: installation_id, platform: "MACOS", app_version: "1.4.0", headers: {})
    post "/graphql",
      params: { query: mutation, variables: { input: { installationId: id, platform: platform, appVersion: app_version } } }.to_json,
      headers: { "Content-Type" => "application/json" }.merge(headers)
    JSON.parse(response.body)
  end

  it "registers without an API key and returns a working token" do
    body = register
    payload = body.dig("data", "registerInstallation")

    expect(response).to have_http_status(:ok)
    expect(payload["token"]).to start_with("bql_test_")
    expect(payload["installationId"]).to eq(installation_id)
    expect(payload["dailyLimit"]).to eq(1000)

    installation = Installation.find_by!(installation_id: installation_id)
    expect(installation).to have_attributes(platform: "macos", app_version: "1.4.0")
    expect(installation.api_keys.sole).to have_attributes(kind: "installation", email: nil)

    post "/graphql", params: { query: "{ books { bookId } }" }, headers: auth_headers(payload["token"])
    expect(response).to have_http_status(:ok)
  end

  it "stores only a digest of the token" do
    token = register.dig("data", "registerInstallation", "token")
    key = ApiKey.installation_keys.sole

    expect(key.token_digest).not_to include(token)
    expect(BCrypt::Password.new(key.token_digest)).to eq(token)
  end

  it "re-registering revokes the previous token and issues a new one" do
    first = register.dig("data", "registerInstallation", "token")
    second = register(app_version: "1.5.0").dig("data", "registerInstallation", "token")

    expect(second).not_to eq(first)
    expect(Installation.count).to eq(1)
    expect(Installation.sole.app_version).to eq("1.5.0")
    expect(ApiKey.installation_keys.active.count).to eq(1)

    post "/graphql", params: { query: "{ books { bookId } }" }, headers: auth_headers(first)
    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body).dig("errors", 0, "extensions", "code")).to eq("UNAUTHENTICATED")

    post "/graphql", params: { query: "{ books { bookId } }" }, headers: auth_headers(second)
    expect(response).to have_http_status(:ok)
  end

  it "refuses a revoked installation" do
    create(:installation, installation_id: installation_id).revoke!

    body = register
    expect(body.dig("errors", 0, "extensions", "code")).to eq("INSTALLATION_REVOKED")
    expect(body.dig("data", "registerInstallation")).to be_nil
    expect(ApiKey.count).to eq(0)
  end

  it "rejects an installation id that is not a UUID" do
    body = register(id: "not-a-uuid")
    expect(body.dig("errors", 0, "extensions", "code")).to eq("INVALID_INPUT")
    expect(Installation.count).to eq(0)
  end

  it "rejects a malformed app version" do
    body = register(app_version: "1.0; DROP TABLE")
    expect(body.dig("errors", 0, "extensions", "code")).to eq("INVALID_INPUT")
  end

  it "requires an API key when the mutation also selects another field" do
    post "/graphql", params: {
      query: %(mutation { registerInstallation(input: {installationId: "#{installation_id}", platform: MACOS, appVersion: "1"}) { token } trackImageDownload(input: {imageId: "abc"}) { queued } })
    }
    expect(response).to have_http_status(:unauthorized)
    expect(Installation.count).to eq(0)
  end

  it "requires an API key for queries" do
    post "/graphql", params: { query: "{ registerInstallation }" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "does not skip auth for a registration sent with an Authorization header" do
    register(headers: auth_headers("bql_test_garbage"))
    expect(response).to have_http_status(:unauthorized)
  end

  it "does not let a fragment smuggle in other fields" do
    post "/graphql", params: {
      query: "mutation { ...F } fragment F on Mutation { testField }"
    }
    expect(response).to have_http_status(:unauthorized)
  end
end
