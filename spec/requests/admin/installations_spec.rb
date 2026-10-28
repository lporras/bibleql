require "rails_helper"

RSpec.describe "Admin installations and installation keys", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:admin_user, email: "admin@example.com", password: "password") }
  let(:installation) { create(:installation, platform: "linux", app_version: "1.2.3") }
  let!(:api_key) { create(:api_key, :installation, installation: installation) }

  before { sign_in admin }

  it "lists installations" do
    get admin_installations_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(installation.installation_id, "1.2.3")
  end

  it "shows an installation with its keys" do
    get admin_installation_path(installation)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(api_key.token_prefix, "Revoke Installation")
  end

  it "revokes an installation and its keys" do
    put revoke_admin_installation_path(installation)

    expect(installation.reload).to be_revoked
    expect(api_key.reload).to be_revoked
  end

  it "shows an installation key without the email-based regenerate action" do
    get admin_api_key_path(api_key)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("installation", "Mark Deprecated")
    expect(response.body).not_to include("Regenerate &amp; Resend")
  end

  it "lists keys of both kinds" do
    developer = create(:api_key)
    get admin_api_keys_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(api_key.token_prefix, developer.token_prefix)
  end

  it "marks a key deprecated and back" do
    put deprecate_admin_api_key_path(api_key)
    expect(api_key.reload).to be_deprecated

    put undeprecate_admin_api_key_path(api_key)
    expect(api_key.reload).not_to be_deprecated
  end
end
