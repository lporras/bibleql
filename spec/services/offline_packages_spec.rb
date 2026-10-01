require "rails_helper"

RSpec.describe OfflinePackages do
  let(:env) do
    { "OFFLINE_R2_ACCOUNT_ID" => "acct", "OFFLINE_R2_ACCESS_KEY_ID" => "key", "OFFLINE_R2_SECRET_ACCESS_KEY" => "secret",
      "OFFLINE_R2_BUCKET" => "bucket", "OFFLINE_PUBLIC_BASE_URL" => "https://downloads.example.com" }
  end

  def with_env(values)
    originals = OfflinePackages::CONFIG_ENV.values.to_h { |name| [ name, ENV[name] ] }
    OfflinePackages::CONFIG_ENV.each_value { |name| ENV.delete(name) }
    values.each { |name, value| ENV[name] = value }
    yield
  ensure
    originals.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end

  describe ".configured?" do
    it "is true when every setting is present" do
      with_env(env) { expect(described_class).to be_configured }
    end

    it "is false when a setting is missing" do
      with_env(env.except("OFFLINE_R2_BUCKET")) { expect(described_class).not_to be_configured }
    end
  end

  describe ".s3_client" do
    it "points at the account's R2 endpoint" do
      with_env(env) do
        expect(described_class.s3_client.config.endpoint.to_s).to eq("https://acct.r2.cloudflarestorage.com")
      end
    end

    it "raises when storage is not configured" do
      with_env({}) { expect { described_class.s3_client }.to raise_error(OfflinePackages::NotConfigured) }
    end
  end

  describe ".enqueue_export" do
    include ActiveJob::TestHelper

    let(:translation) { create(:translation, offline_downloadable: true) }

    it "enqueues when the translation is downloadable and storage is configured" do
      with_env(env) do
        expect { described_class.enqueue_export(translation) }.to have_enqueued_job(ExportOfflinePackageJob).with(translation.id)
      end
    end

    it "does nothing for a non-downloadable translation" do
      translation.update!(offline_downloadable: false)
      with_env(env) do
        expect { described_class.enqueue_export(translation) }.not_to have_enqueued_job(ExportOfflinePackageJob)
      end
    end

    it "does nothing when storage is not configured" do
      with_env({}) do
        expect { described_class.enqueue_export(translation) }.not_to have_enqueued_job(ExportOfflinePackageJob)
      end
    end
  end
end
