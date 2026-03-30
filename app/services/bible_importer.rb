class BibleImporter
  CANONICAL_BOOK_IDS = %w[
    GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH EST JOB PSA PRO
    ECC SNG ISA JER LAM EZK DAN HOS JOL AMO OBA JON MIC NAM HAB ZEP HAG ZEC MAL
    MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM HEB
    JAS 1PE 2PE 1JN 2JN 3JN JUD REV
  ].freeze

  OT_BOOKS = CANONICAL_BOOK_IDS[0..38].to_set.freeze
  NT_BOOKS = CANONICAL_BOOK_IDS[39..].to_set.freeze

  attr_reader :file_path, :identifier

  def initialize(file_path:)
    @file_path = file_path
    @identifier = File.basename(file_path).sub(/\.(usfx|osis|zefania)\.xml$/i, "")
  end

  def import!
    bible = BibleParser.new(File.open(file_path))
    books_data = bible.books.select { |b| CANONICAL_BOOK_IDS.include?(b.id) }

    return if books_data.empty?

    ActiveRecord::Base.transaction do
      translation = find_or_create_translation(books_data)
      clear_existing_data(translation)
      book_records = ensure_books(books_data)
      create_book_names(translation, books_data, book_records)
      import_verses(translation, bible, book_records)
    end
  rescue => e
    puts "  ERROR: #{e.message} (#{e.class})"
  end

  def self.import_all(directory: "db/open-bibles")
    Dir.glob(File.join(directory, "*.xml")).sort.each do |file_path|
      identifier = File.basename(file_path).sub(/\.(usfx|osis|zefania)\.xml$/i, "")
      puts "Importing #{identifier}..."
      new(file_path: file_path).import!
      count = Translation.find_by(identifier: identifier)&.verses&.count || 0
      puts "  Done. Verses: #{count}" if count > 0
    end
  end

  private

  def find_or_create_translation(books_data)
    language = identifier.split("-").first
    Translation.find_or_create_by!(identifier: identifier) do |t|
      t.name = identifier
      t.language = language
      t.note = "Public Domain"
    end
  end

  def clear_existing_data(translation)
    translation.verses.delete_all
    translation.book_names.delete_all
  end

  def ensure_books(books_data)
    books_data.each_with_object({}) do |book_data, hash|
      next unless CANONICAL_BOOK_IDS.include?(book_data.id)

      position = CANONICAL_BOOK_IDS.index(book_data.id) + 1
      testament = OT_BOOKS.include?(book_data.id) ? "OT" : "NT"

      record = Book.find_or_initialize_by(book_id: book_data.id)
      if record.new_record?
        record.assign_attributes(
          name: book_data.title,
          testament: testament,
          position: position
        )
        record.save!
      end

      hash[book_data.id] = record
    end
  end

  def create_book_names(translation, books_data, book_records)
    names = books_data.filter_map do |book_data|
      record = book_records[book_data.id]
      next unless record

      {
        translation_id: translation.id,
        book_id: record.id,
        name: book_data.title,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    BookName.insert_all(names) if names.any?
  end

  def import_verses(translation, bible, book_records)
    batch = []

    bible.each_verse do |verse|
      next unless CANONICAL_BOOK_IDS.include?(verse.book_id)
      next if verse.text.nil? || verse.text.strip.empty?

      book_record = book_records[verse.book_id]
      next unless book_record

      batch << {
        translation_id: translation.id,
        book_id: book_record.id,
        chapter: verse.chapter_num,
        verse_number: verse.num,
        text: verse.text.strip,
        created_at: Time.current,
        updated_at: Time.current
      }

      if batch.size >= 1000
        Verse.insert_all(batch)
        batch.clear
      end
    end

    Verse.insert_all(batch) if batch.any?
  end
end
