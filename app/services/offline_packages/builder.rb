# frozen_string_literal: true

require "sqlite3"

module OfflinePackages
  # Writes one translation to a standalone SQLite file following schema_v1.sql.
  #
  # verses.id is assigned in canonical order (book position, chapter, verse), so
  # clients get the exhaustive canonical concordance ordering with a plain ORDER BY id.
  class Builder
    SCHEMA_VERSION = 1
    APPLICATION_ID = 0x42514C31
    SCHEMA_SQL = Rails.root.join("app/services/offline_packages/schema_v1.sql").read.freeze

    attr_reader :translation

    def initialize(translation)
      unless translation.offline_downloadable?
        raise NotDownloadable, "#{translation.identifier} is not flagged offline_downloadable"
      end

      @translation = translation
    end

    # Writes an uncompressed SQLite file to `path` (replacing any file there).
    # Returns the source digest.
    def build(path)
      FileUtils.rm_f(path)
      db = SQLite3::Database.new(path.to_s)
      db.execute_batch(SCHEMA_SQL)

      db.transaction do
        insert_books(db)
        insert_verses(db)
        insert_meta(db)
      end

      db.execute("INSERT INTO verses_fts(verses_fts) VALUES('rebuild')")
      db.execute("PRAGMA journal_mode = DELETE")
      db.execute("VACUUM")
      source_digest
    ensure
      db&.close
    end

    # Digest of the data (not the file bytes), so an unchanged translation can skip
    # re-uploading. Covers everything written except exported_at.
    def source_digest
      @source_digest ||= Digest::SHA256.hexdigest(
        { schema: SCHEMA_VERSION, meta: translation_meta, books: book_rows, verses: verse_rows }.to_json
      )
    end

    def verse_count
      verse_rows.size
    end

    private

    # ~31k rows fit comfortably in memory; one ordered pluck keeps canonical order.
    def verse_rows
      @verse_rows ||= translation.verses
        .joins(:book)
        .order("books.position", "verses.chapter", "verses.verse_number")
        .pluck("books.position", "verses.chapter", "verses.verse_number", "verses.text")
    end

    # [position, code, localized name, testament, chapter count]
    def book_rows
      @book_rows ||= BibleIndexBuilder.new(translation: translation).call.map do |book|
        [ book.position, book.book_id, book.name, book.testament, book.chapter_count ]
      end
    end

    def translation_meta
      {
        "translation_identifier" => translation.identifier,
        "translation_name" => translation.name,
        "translation_abbrev" => translation.abbrev,
        "language_code" => translation.language,
        "language_name" => translation.language_name,
        "license_note" => translation.note
      }
    end

    def insert_books(db)
      insert_rows(db, "INSERT INTO books (id, code, name, testament, chapters) VALUES (?, ?, ?, ?, ?)", book_rows)
    end

    def insert_verses(db)
      rows = verse_rows.each.with_index(1).map { |(book, chapter, verse, text), id| [ id, book, chapter, verse, text ] }
      insert_rows(db, "INSERT INTO verses (id, book_id, chapter, verse, text) VALUES (?, ?, ?, ?, ?)", rows)
    end

    def insert_meta(db)
      meta = translation_meta.merge(
        "schema_version" => SCHEMA_VERSION,
        "source_digest" => source_digest,
        "exported_at" => Time.current.utc.iso8601,
        "verse_count" => verse_count
      )
      rows = meta.map { |key, value| [ key, value.to_s ] }
      insert_rows(db, "INSERT INTO meta (key, value) VALUES (?, ?)", rows)
    end

    def insert_rows(db, sql, rows)
      stmt = db.prepare(sql)
      rows.each { |row| stmt.execute(row) }
    ensure
      stmt&.close
    end
  end
end
