# frozen_string_literal: true

module Sources
  # Batch-loads OfflinePackage rows by translation id, so listing
  # `translations { offlinePackage { ... } }` runs one query instead of one per translation.
  class OfflinePackageSource < GraphQL::Dataloader::Source
    def initialize(schema_version)
      @schema_version = schema_version
    end

    def fetch(translation_ids)
      packages = OfflinePackage
        .where(translation_id: translation_ids, schema_version: @schema_version)
        .index_by(&:translation_id)
      translation_ids.map { |id| packages[id] }
    end
  end
end
