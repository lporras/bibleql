# frozen_string_literal: true

# Offline translation packages: prebuilt, gzipped SQLite files that clients download
# once and read without the API. See docs/offline_packages.md for the file format.
#
#   Builder   Postgres → SQLite file (schema_v1.sql)
#   Publisher gzip + upload to Cloudflare R2
#   ExportOfflinePackageJob ties them together and records an OfflinePackage row
module OfflinePackages
  class Error < StandardError; end
  class NotDownloadable < Error; end
  class NotConfigured < Error; end

  # ENV wins; Rails credentials (offline_packages.*) are the fallback.
  CONFIG_ENV = {
    account_id: "OFFLINE_R2_ACCOUNT_ID",
    access_key_id: "OFFLINE_R2_ACCESS_KEY_ID",
    secret_access_key: "OFFLINE_R2_SECRET_ACCESS_KEY",
    bucket: "OFFLINE_R2_BUCKET",
    public_base_url: "OFFLINE_PUBLIC_BASE_URL"
  }.freeze

  def self.config
    CONFIG_ENV.to_h do |key, env_name|
      [ key, ENV[env_name].presence || Rails.application.credentials.dig(:offline_packages, key).presence ]
    end
  end

  def self.configured?
    config.values.all?(&:present?)
  end

  def self.s3_client
    raise NotConfigured, "Set #{CONFIG_ENV.values.join(', ')}" unless configured?

    require "aws-sdk-s3"
    settings = config
    Aws::S3::Client.new(
      access_key_id: settings[:access_key_id],
      secret_access_key: settings[:secret_access_key],
      endpoint: "https://#{settings[:account_id]}.r2.cloudflarestorage.com",
      region: "auto",
      # R2 rejects some of the newer default flexible checksums
      request_checksum_calculation: "when_required",
      response_checksum_validation: "when_required"
    )
  end

  # Called at the end of every import so fixing an import bug republishes the package.
  def self.enqueue_export(translation)
    return unless translation&.offline_downloadable? && configured?

    ExportOfflinePackageJob.perform_later(translation.id)
  end
end
