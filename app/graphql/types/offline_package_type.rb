# frozen_string_literal: true

module Types
  class OfflinePackageType < Types::BaseObject
    description "A downloadable SQLite package of one translation for offline use. " \
      "Download `url`, verify `sha256`, gunzip, then open the file. See the offline packages documentation for its format."

    field :url, String, null: false,
      description: "Public HTTPS URL of the gzipped SQLite file. Immutable: a new export gets a new URL."
    field :sha256, String, null: false, description: "Hex SHA-256 of the gzipped file, to verify the download"
    field :size_bytes, Integer, null: false, description: "Download size in bytes (gzipped)"
    field :uncompressed_size_bytes, Integer, null: false, description: "Disk space needed once gunzipped, in bytes"
    field :schema_version, Integer, null: false,
      description: "Package format version (SQLite `PRAGMA user_version`)"
    field :verse_count, Integer, null: false, description: "Number of verses in the package"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When this package was last published"
  end
end
