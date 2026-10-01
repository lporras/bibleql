# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL offlinePackage field", type: :request do
  let(:api_key) { create(:api_key, environment: "test") }
  let(:headers) { auth_headers(api_key.token) }
  let!(:web) { create(:translation, identifier: "eng-web", offline_downloadable: true) }
  let!(:kjv) { create(:translation, identifier: "eng-kjv", name: "King James Version", offline_downloadable: true) }
  let!(:niv) { create(:translation, identifier: "eng-niv", name: "New International Version", note: "Copyright") }
  let!(:web_package) { create(:offline_package, translation: web) }

  def query(graphql)
    post "/graphql", params: { query: graphql }, headers: headers
    JSON.parse(response.body)
  end

  it "returns the package for an exported, downloadable translation" do
    data = query('{ translation(identifier: "eng-web") { offlineDownloadable offlinePackage {
      url sha256 sizeBytes uncompressedSizeBytes schemaVersion verseCount updatedAt } } }')["data"]["translation"]

    expect(data["offlineDownloadable"]).to be(true)
    expect(data["offlinePackage"]).to include(
      "url" => web_package.url, "sha256" => web_package.sha256, "sizeBytes" => 1_234_567,
      "uncompressedSizeBytes" => 4_567_890, "schemaVersion" => 1, "verseCount" => 31_102
    )
  end

  it "is null for a downloadable translation that has not been exported" do
    data = query('{ translation(identifier: "eng-kjv") { offlinePackage { url } } }')["data"]["translation"]
    expect(data["offlinePackage"]).to be_nil
  end

  it "is null for a non-downloadable translation, even if a package row exists" do
    create(:offline_package, translation: niv)
    data = query('{ translation(identifier: "eng-niv") { offlineDownloadable offlinePackage { url } } }')["data"]["translation"]

    expect(data).to eq("offlineDownloadable" => false, "offlinePackage" => nil)
  end

  it "is null for a schema version that was never published" do
    data = query('{ translation(identifier: "eng-web") { offlinePackage(schemaVersion: 2) { url } } }')["data"]["translation"]
    expect(data["offlinePackage"]).to be_nil
  end

  it "loads packages for every translation in one query" do
    create(:offline_package, translation: kjv)

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?("offline_packages") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      result = query("{ translations { identifier offlinePackage { url } } }")
      packages = result["data"]["translations"].to_h { |t| [ t["identifier"], t["offlinePackage"] ] }
      expect(packages["eng-web"]).to be_present
      expect(packages["eng-kjv"]).to be_present
      expect(packages["eng-niv"]).to be_nil
    end

    expect(queries.size).to eq(1)
  end
end
