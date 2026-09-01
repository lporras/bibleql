# frozen_string_literal: true

# Imports the translations in db/biblelist/ (downloaded from
# https://biblelist.netlify.app/), which use a different XML shape than the
# open-bibles submodule — see BiblelistFormat::Parser.
#
# Two things those files do not carry, and where each comes from instead:
#   * a stable identifier, language code and abbreviation → config/biblelist_translations.yml
#   * book names of any kind (books are bare ordinals 1-66) → copied from the
#     `book_names_from` translation, which must already be imported
class BiblelistImporter
  class Error < StandardError; end
  class UnknownTranslationError < Error; end
  class MissingFileError < Error; end
  class MissingBooksError < Error; end
  class MissingReferenceError < Error; end

  CONFIG = YAML.load_file(Rails.root.join("config", "biblelist_translations.yml")).freeze
  DIRECTORY = Rails.root.join("db", "biblelist")
  BATCH_SIZE = 1000

  attr_reader :identifier, :metadata, :file_path

  def self.identifiers = CONFIG.keys

  def self.import_all(directory: DIRECTORY)
    identifiers.each do |identifier|
      puts "Importing #{identifier}..."
      count = new(identifier: identifier, directory: directory).import!
      puts "  Done. Verses: #{count}"
    rescue Error => e
      puts "  SKIPPED: #{e.message}"
    end
  end

  def initialize(identifier:, directory: DIRECTORY)
    @identifier = identifier
    @metadata = CONFIG[identifier] or raise UnknownTranslationError,
      "#{identifier} is not listed in config/biblelist_translations.yml"
    @file_path = Pathname.new(directory).join(metadata["file"])
    raise MissingFileError, "#{file_path} not found" unless File.exist?(file_path)
  end

  # Returns the number of verses imported.
  def import!
    book_records = fetch_books
    book_names = reference_book_names

    File.open(file_path) do |io|
      parser = BiblelistFormat::Parser.new(io)
      attributes = parser.bible_attributes

      ActiveRecord::Base.transaction do
        translation = upsert_translation(attributes)
        clear_existing_data(translation)
        create_book_names(translation, book_records, book_names)
        import_verses(translation, parser, book_records)
      end
    end
  end

  private

  def upsert_translation(attributes)
    translation = Translation.find_or_initialize_by(identifier: identifier)
    translation.assign_attributes(
      name: metadata["name"].presence || attributes["title"].presence || attributes["translation"].presence || identifier,
      abbrev: metadata["abbrev"],
      language: metadata["language"],
      language_name: metadata["language_name"],
      note: metadata["note"].presence || attributes["status"].presence || attributes["info"].presence
    )
    translation.save!
    translation
  end

  def clear_existing_data(translation)
    translation.verses.delete_all
    translation.book_names.delete_all
  end

  # These files never create Book rows — they carry no book names to create them
  # from. The canonical 66 come from the open-bibles import.
  def fetch_books
    records = Book.where(book_id: BibleImporter::CANONICAL_BOOK_IDS).index_by(&:book_id)
    missing = BibleImporter::CANONICAL_BOOK_IDS - records.keys
    if missing.any?
      raise MissingBooksError,
        "#{missing.size} canonical books are missing (#{missing.first(3).join(', ')}...). Run: rake bible:import"
    end

    records
  end

  # book_id (e.g. "MAT") => localized name (e.g. "Mateo")
  def reference_book_names
    reference = metadata["book_names_from"]
    return {} if reference.blank?

    names = BookName.joins(:book, :translation)
      .where(translations: { identifier: reference })
      .pluck("books.book_id", "book_names.name")
      .to_h

    if names.empty?
      raise MissingReferenceError,
        "#{identifier} takes its book names from #{reference}, which has none. Run: rake \"bible:import_one[#{reference}]\""
    end

    names
  end

  def create_book_names(translation, book_records, book_names)
    rows = book_records.filter_map do |book_id, record|
      name = book_names[book_id] || record.name
      next if name.blank?

      {
        translation_id: translation.id,
        book_id: record.id,
        name: name,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    BookName.insert_all(rows) if rows.any?
  end

  def import_verses(translation, parser, book_records)
    imported = 0
    batch = []

    parser.each_verse do |verse|
      book_record = book_records[verse.book_id]
      next unless book_record
      next if verse.text.nil? || verse.text.strip.empty?

      batch << {
        translation_id: translation.id,
        book_id: book_record.id,
        chapter: verse.chapter_num,
        verse_number: verse.num,
        text: verse.text.strip,
        created_at: Time.current,
        updated_at: Time.current
      }

      next if batch.size < BATCH_SIZE

      imported += insert_verses(batch)
      batch = []
    end

    imported + insert_verses(batch)
  end

  # These files are third-party and occasionally repeat a verse number; skip the
  # duplicates rather than losing the whole import to the uniqueness index.
  def insert_verses(batch)
    return 0 if batch.empty?

    Verse.insert_all(batch, unique_by: :index_verses_uniqueness).length
  end
end
