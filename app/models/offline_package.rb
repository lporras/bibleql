# A published offline SQLite package for one translation and package schema version.
# Rows are upserted by ExportOfflinePackageJob; see docs/offline_packages.md.
class OfflinePackage < ApplicationRecord
  belongs_to :translation

  validates :schema_version, :storage_key, :url, :sha256, :source_digest, presence: true
  validates :schema_version, uniqueness: { scope: :translation_id }
end
