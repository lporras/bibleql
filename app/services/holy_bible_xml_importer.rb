# frozen_string_literal: true

# Imports the translations in db/holy-bible-xml/ (the Holy-Bible-XML-Format
# submodule, https://github.com/lporras/Holy-Bible-XML-Format) — a 1000+ file,
# 200+ language collection using the same <bible><testament><book number> XML
# shape as db/biblelist/, parsed by the same BiblelistFormat::Parser.
#
# Unlike BiblelistImporter, there is no per-file metadata table: identifier,
# language code, and abbreviation are all derived from the filename itself by
# HolyBibleXmlFilenameParser (best-effort — see config/language_codes.yml).
# Book names are copied from whichever already-imported translation of the
# same language has the most of them, falling back to the canonical Book name.
class HolyBibleXmlImporter
  class Error < StandardError; end
  class UnknownTranslationError < Error; end
  class MissingBooksError < Error; end

  DIRECTORY = Rails.root.join("db", "holy-bible-xml")
  BATCH_SIZE = 1000

  attr_reader :file_path, :identifier, :language_code, :language_name, :variant, :abbrev

  def self.import_all(directory: DIRECTORY)
    Dir.glob(File.join(directory, "*.xml")).sort.each do |path|
      parsed = HolyBibleXmlFilenameParser.call(path)

      if Translation.exists?(identifier: parsed.identifier)
        puts "SKIPPED (already imported): #{parsed.identifier}"
        next
      end

      puts "Importing #{parsed.identifier} (#{File.basename(path)})..."
      count = new(file_path: path).import!
      puts "  Done. Verses: #{count}"
    rescue Error => e
      puts "  SKIPPED: #{e.message}"
    end
  end

  # Looks up the file that derives `identifier` and imports just that one.
  # Skips (without parsing anything) if that identifier is already imported.
  def self.import_one(identifier, directory: DIRECTORY)
    path = Dir.glob(File.join(directory, "*.xml")).find do |candidate|
      HolyBibleXmlFilenameParser.call(candidate).identifier == identifier
    end
    raise UnknownTranslationError, "no file in #{directory} derives the identifier \"#{identifier}\"" unless path

    if Translation.exists?(identifier: identifier)
      puts "#{identifier} is already imported. Nothing to do."
      return
    end

    puts "Importing #{identifier} (#{File.basename(path)})..."
    count = new(file_path: path).import!
    puts "Done. Verses: #{count}"
  end

  def initialize(file_path:)
    @file_path = file_path

    parsed = HolyBibleXmlFilenameParser.call(file_path)
    @identifier = parsed.identifier
    @language_code = parsed.language_code
    @language_name = parsed.language_name
    @variant = parsed.variant
    @abbrev = parsed.abbrev
  end

  # Returns the number of verses imported.
  def import!
    book_records = fetch_books
    book_names = reference_book_names
    translation = nil
    imported_count = 0

    File.open(file_path) do |io|
      parser = BiblelistFormat::Parser.new(io)
      attributes = parser.bible_attributes

      ActiveRecord::Base.transaction do
        translation = upsert_translation(attributes)
        clear_existing_data(translation)
        create_book_names(translation, book_records, book_names)
        imported_count = import_verses(translation, parser, book_records)
      end
    end

    ConcordanceIndexer.new(translation).call
    imported_count
  end

  private

  def upsert_translation(attributes)
    translation = Translation.find_or_initialize_by(identifier: identifier)
    translation.assign_attributes(
      name: attributes["translation"].presence || attributes["title"].presence || humanized_name,
      abbrev: abbrev,
      language: language_code,
      language_name: language_name,
      note: attributes["status"].presence || attributes["info"].presence
    )
    translation.save!
    translation
  end

  def humanized_name
    [ language_name, variant.presence&.tr("-", " ")&.titleize ].compact.join(" ")
  end

  def clear_existing_data(translation)
    translation.verses.delete_all
    translation.book_names.delete_all
  end

  # These files never create Book rows — the canonical 66 come from the
  # open-bibles import.
  def fetch_books
    records = Book.where(book_id: BibleImporter::CANONICAL_BOOK_IDS).index_by(&:book_id)
    missing = BibleImporter::CANONICAL_BOOK_IDS - records.keys
    if missing.any?
      raise MissingBooksError,
        "#{missing.size} canonical books are missing (#{missing.first(3).join(', ')}...). Run: rake bible:import"
    end

    records
  end

  # book_id (e.g. "MAT") => name, copied from whichever already-imported
  # translation of the same language has the most book names. Falls back to
  # the canonical Book#name (in create_book_names) when none exists yet.
  def reference_book_names
    reference = Translation.where(language: language_code)
      .joins(:book_names)
      .group("translations.id")
      .order(Arel.sql("COUNT(book_names.id) DESC"))
      .first
    return {} unless reference

    BookName.joins(:book).where(translation_id: reference.id).pluck("books.book_id", "book_names.name").to_h
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

  # These files are third-party and occasionally repeat a verse number; skip
  # the duplicates rather than losing the whole import to the uniqueness index.
  def insert_verses(batch)
    return 0 if batch.empty?

    Verse.insert_all(batch, unique_by: :index_verses_uniqueness).length
  end
end
