# Builds, uploads and records the offline package for one translation.
# Skips the upload when the source data hasn't changed since the last export.
class ExportOfflinePackageJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(translation_id, **) { "offline-export-#{translation_id}" }, duration: 30.minutes

  def perform(translation_id, force: false)
    translation = Translation.find(translation_id)
    builder = OfflinePackages::Builder.new(translation)
    schema_version = OfflinePackages::Builder::SCHEMA_VERSION

    existing = translation.offline_packages.find_by(schema_version: schema_version)
    return if existing && existing.source_digest == builder.source_digest && !force

    Dir.mktmpdir("offline-#{translation.identifier}") do |dir|
      path = File.join(dir, "#{translation.identifier}.sqlite")
      builder.build(path)
      result = OfflinePackages::Publisher.new(translation, path).publish

      OfflinePackage.upsert(
        result.merge(
          translation_id: translation.id,
          schema_version: schema_version,
          source_digest: builder.source_digest,
          verse_count: builder.verse_count
        ),
        unique_by: [ :translation_id, :schema_version ]
      )
    end
  end
end
