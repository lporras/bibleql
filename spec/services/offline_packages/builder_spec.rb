require "rails_helper"

RSpec.describe OfflinePackages::Builder do
  let(:translation) do
    create(:translation, identifier: "spa-test", name: "Biblia de Prueba", language: "spa",
      language_name: "Spanish", abbrev: "BP", note: "Public Domain", offline_downloadable: true)
  end
  let(:genesis) { create(:book, book_id: "GEN", name: "Genesis", testament: "OT", position: 1) }
  let(:john) { create(:book, book_id: "JHN", name: "John", testament: "NT", position: 43) }
  let(:path) { Rails.root.join("tmp", "builder_spec_#{Process.pid}.sqlite").to_s }

  before do
    create(:book_name, translation: translation, book: genesis, name: "Génesis")
    create(:book_name, translation: translation, book: john, name: "Juan")
    # Created out of canonical order on purpose
    create(:verse, translation: translation, book: john, chapter: 3, verse_number: 16,
      text: "Porque de tal manera amó Dios al mundo")
    create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 2,
      text: "y el Espíritu de Dios se movía sobre la faz de las aguas")
    create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 1,
      text: "En el principio creó Dios los cielos y la tierra")
  end

  after { FileUtils.rm_f(path) }

  def build_and_open
    described_class.new(translation).build(path)
    SQLite3::Database.new(path, readonly: true)
  end

  it "has FTS5 compiled into the bundled SQLite" do
    db = SQLite3::Database.new(":memory:")
    expect(db.get_first_value("SELECT sqlite_compileoption_used('ENABLE_FTS5')")).to eq(1)
  ensure
    db&.close
  end

  it "refuses a translation that is not offline-downloadable" do
    translation.update!(offline_downloadable: false)
    expect { described_class.new(translation) }.to raise_error(OfflinePackages::NotDownloadable)
  end

  it "stamps the file with the BQL1 application id and schema version" do
    db = build_and_open
    expect(db.get_first_value("PRAGMA application_id")).to eq(0x42514C31)
    expect(db.get_first_value("PRAGMA user_version")).to eq(1)
    expect(db.get_first_value("PRAGMA journal_mode")).to eq("delete")
    expect(db.get_first_value("PRAGMA integrity_check")).to eq("ok")
  ensure
    db&.close
  end

  it "writes books with localized names and chapter counts" do
    db = build_and_open
    rows = db.execute("SELECT id, code, name, testament, chapters FROM books ORDER BY id")
    expect(rows).to eq([ [ 1, "GEN", "Génesis", "OT", 1 ], [ 43, "JHN", "Juan", "NT", 1 ] ])
  ensure
    db&.close
  end

  it "assigns verse ids in canonical order" do
    db = build_and_open
    rows = db.execute("SELECT id, book_id, chapter, verse FROM verses ORDER BY id")
    expect(rows).to eq([ [ 1, 1, 1, 1 ], [ 2, 1, 1, 2 ], [ 3, 43, 3, 16 ] ])
  ensure
    db&.close
  end

  it "writes the meta table" do
    db = build_and_open
    meta = db.execute("SELECT key, value FROM meta").to_h
    expect(meta).to include(
      "schema_version" => "1", "translation_identifier" => "spa-test", "translation_name" => "Biblia de Prueba",
      "language_code" => "spa", "language_name" => "Spanish", "license_note" => "Public Domain", "verse_count" => "3"
    )
    expect(meta["source_digest"]).to eq(described_class.new(translation).source_digest)
    expect { Time.iso8601(meta["exported_at"]) }.not_to raise_error
  ensure
    db&.close
  end

  it "builds a diacritic-insensitive full-text index" do
    db = build_and_open
    ids = db.execute("SELECT rowid FROM verses_fts WHERE verses_fts MATCH 'espiritu'").flatten
    expect(ids).to eq([ 2 ])
  ensure
    db&.close
  end

  describe "#source_digest" do
    it "is stable for unchanged data and changes when a verse changes" do
      digest = described_class.new(translation).source_digest
      expect(described_class.new(translation).source_digest).to eq(digest)

      translation.verses.first.update!(text: "changed")
      expect(described_class.new(translation).source_digest).not_to eq(digest)
    end
  end
end
