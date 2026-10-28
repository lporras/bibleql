require "rails_helper"

RSpec.describe "Installation heartbeat", type: :request do
  let(:installation) { create(:installation, app_version: "1.0.0", last_seen_at: nil) }
  let!(:api_key) { create(:api_key, :installation, installation: installation) }
  let(:query) { "{ books { bookId } }" }

  def request_with(version: nil)
    headers = auth_headers(api_key.token)
    headers["X-App-Version"] = version if version
    post "/graphql", params: { query: query }, headers: headers
  end

  it "records last_seen_at and the reported app version" do
    freeze_time do
      request_with(version: "1.1.0")
      expect(installation.reload).to have_attributes(last_seen_at: Time.current, app_version: "1.1.0")
    end
  end

  it "writes at most once per hour while the version is unchanged" do
    travel_to(Time.utc(2026, 10, 27, 10, 0)) { request_with }
    travel_to(Time.utc(2026, 10, 27, 10, 30)) { request_with }
    expect(installation.reload.last_seen_at).to eq(Time.utc(2026, 10, 27, 10, 0))

    travel_to(Time.utc(2026, 10, 27, 11, 1)) { request_with }
    expect(installation.reload.last_seen_at).to eq(Time.utc(2026, 10, 27, 11, 1))
  end

  it "writes immediately when the version changes" do
    travel_to(Time.utc(2026, 10, 27, 10, 0)) { request_with }
    travel_to(Time.utc(2026, 10, 27, 10, 5)) { request_with(version: "2.0.0") }

    expect(installation.reload).to have_attributes(app_version: "2.0.0", last_seen_at: Time.utc(2026, 10, 27, 10, 5))
  end

  it "ignores a malformed version header" do
    request_with(version: "<script>")
    expect(installation.reload.app_version).to eq("1.0.0")
  end
end
