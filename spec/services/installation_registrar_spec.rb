require "rails_helper"

RSpec.describe InstallationRegistrar do
  let(:installation_id) { SecureRandom.uuid }

  def register(**overrides)
    described_class.call(installation_id: installation_id, platform: "windows", app_version: "1.0.0", **overrides)
  end

  it "creates the installation and an installation key whose plaintext token is returned once" do
    key = register

    expect(key).to be_persisted
    expect(key).to have_attributes(kind: "installation", environment: "test", daily_limit: 1000, name: "windows installation")
    expect(key.token).to start_with("bql_test_")
    expect(ApiKey.find(key.id).token).to be_nil
    expect(key.installation).to have_attributes(installation_id: installation_id, platform: "windows")
  end

  it "normalizes the installation id to lowercase" do
    register(installation_id: installation_id.upcase)
    expect(Installation.sole.installation_id).to eq(installation_id)
  end

  it "revokes previous keys on re-registration and updates platform/version" do
    first = register
    second = register(platform: "linux", app_version: "2.0.0")

    expect(first.reload).to be_revoked
    expect(second).not_to be_revoked
    expect(second.installation.reload).to have_attributes(platform: "linux", app_version: "2.0.0")
    expect(ApiKey.authenticate(first.token)).to be_nil
    expect(ApiKey.authenticate(second.token)).to eq(second)
  end

  it "raises Revoked for a revoked installation" do
    create(:installation, installation_id: installation_id).revoke!
    expect { register }.to raise_error(described_class::Revoked)
  end

  it "raises RecordInvalid for bad input without leaving rows behind" do
    expect { register(platform: "beos") }.to raise_error(ActiveRecord::RecordInvalid)
    expect(Installation.count).to eq(0)
    expect(ApiKey.count).to eq(0)
  end

  it "recovers when a concurrent registration wins the insert race" do
    winner = create(:installation, installation_id: installation_id)
    allow(Installation).to receive(:find_by).and_call_original
    allow(Installation).to receive(:find_by).with(installation_id: installation_id).and_return(nil)

    key = register
    expect(key.installation).to eq(winner)
    expect(Installation.count).to eq(1)
  end
end
