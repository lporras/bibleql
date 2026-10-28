require "rails_helper"

RSpec.describe Installation, type: :model do
  describe "validations" do
    it "is valid with a UUID, known platform and version" do
      expect(build(:installation)).to be_valid
    end

    it "requires a UUID installation_id" do
      expect(build(:installation, installation_id: "abc")).not_to be_valid
    end

    it "requires a unique installation_id" do
      existing = create(:installation)
      expect(build(:installation, installation_id: existing.installation_id)).not_to be_valid
    end

    it "requires a known platform" do
      expect(build(:installation, platform: "beos")).not_to be_valid
    end

    it "restricts app_version characters and length" do
      expect(build(:installation, app_version: "1.4.0-beta.1+build.7")).to be_valid
      expect(build(:installation, app_version: "1.0 <b>")).not_to be_valid
      expect(build(:installation, app_version: "1" * 33)).not_to be_valid
    end
  end

  describe "#revoke!" do
    it "revokes the installation and all of its active keys" do
      installation = create(:installation)
      keys = create_list(:api_key, 2, :installation, installation: installation)

      installation.revoke!

      expect(installation).to be_revoked
      expect(keys.map { |key| key.reload.revoked? }).to all(be(true))
    end
  end

  describe "#touch_seen!" do
    let(:installation) { create(:installation, app_version: "1.0.0", last_seen_at: nil) }

    it "writes when never seen" do
      freeze_time do
        installation.touch_seen!(nil)
        expect(installation.reload.last_seen_at).to eq(Time.current)
      end
    end

    it "skips the write within the interval when the version is unchanged" do
      installation.update_columns(last_seen_at: 10.minutes.ago)
      expect { installation.touch_seen!("1.0.0") }.not_to(change { installation.reload.last_seen_at })
    end

    it "writes within the interval when the version changes" do
      installation.update_columns(last_seen_at: 10.minutes.ago)
      installation.touch_seen!("1.1.0")
      expect(installation.reload.app_version).to eq("1.1.0")
    end

    it "writes again after the interval" do
      installation.update_columns(last_seen_at: 2.hours.ago)
      expect { installation.touch_seen!(nil) }.to(change { installation.reload.last_seen_at })
    end
  end
end
