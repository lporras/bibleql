# frozen_string_literal: true

# Curated per-translation metadata (display name, abbreviation, language name,
# license) generated from the open-bibles README. See TranslationMetadataGenerator.
class TranslationMetadata
  ALL = YAML.load_file(Rails.root.join("config", "translations.yml")).freeze

  def self.for(identifier)
    ALL[identifier]
  end

  def self.identifiers
    ALL.keys
  end
end
