# frozen_string_literal: true

# Backfills existing Translation rows with the curated metadata in
# config/translations.yml — display name, abbreviation, language name, license.
# Translations imported before that metadata existed carry their identifier as
# their name (e.g. "eng-web") and a hardcoded "Public Domain" note.
class TranslationMetadataSync
  Result = Struct.new(:updated, :unchanged, :missing, keyword_init: true) do
    def summary
      "updated: #{updated.size}, unchanged: #{unchanged.size}, no metadata: #{missing.size}"
    end
  end

  # A row of Result#updated: the translation plus its ActiveModel changes hash
  # ({ "name" => [ "eng-web", "World English Bible" ] }), captured before save so
  # a dry run can report exactly what a real run would write.
  Change = Struct.new(:translation, :changes, keyword_init: true)

  def self.call(...) = new(...).call

  def initialize(identifier: nil, dry_run: false)
    @identifier = identifier
    @dry_run = dry_run
  end

  def call
    result = Result.new(updated: [], unchanged: [], missing: [])

    scope.each do |translation|
      metadata = TranslationMetadata.for(translation.identifier)

      if metadata.nil?
        result.missing << translation
        next
      end

      apply(translation, metadata)

      if translation.changed?
        result.updated << Change.new(translation: translation, changes: translation.changes)
        translation.save! unless @dry_run
      else
        result.unchanged << translation
      end
    end

    result
  end

  private

  def scope
    @identifier ? Translation.where(identifier: @identifier) : Translation.order(:identifier)
  end

  # Never blank out a value we already have just because the YAML lacks one.
  def apply(translation, metadata)
    translation.assign_attributes(
      name: metadata["name"].presence || translation.name,
      note: metadata["note"].presence || translation.note,
      abbrev: metadata["abbrev"].presence || translation.abbrev,
      language_name: metadata["language_name"].presence || translation.language_name
    )
  end
end
