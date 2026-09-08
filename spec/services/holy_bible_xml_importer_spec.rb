require "rails_helper"

RSpec.describe HolyBibleXmlImporter do
  let(:directory) { Rails.root.join("spec/fixtures/holy_bible_xml") }
  let(:file_path) { directory.join("ArabicSVDBible.xml") }

  let(:books) do
    BibleImporter::CANONICAL_BOOK_IDS.each_with_index.to_h do |book_id, index|
      [ book_id, create(:book, book_id: book_id, name: book_id.titleize, testament: index < 39 ? "OT" : "NT", position: index + 1) ]
    end
  end

  before { books }

  def import(path = file_path) = described_class.new(file_path: path).import!

  describe "#initialize" do
    it "derives its identifier/language/abbrev from the filename" do
      importer = described_class.new(file_path: file_path)

      expect(importer).to have_attributes(identifier: "ara-svd", language_code: "ara", abbrev: "SVD")
    end
  end

  describe "#import!" do
    it "creates the translation with metadata derived from the filename and XML attributes" do
      expect { import }.to change(Translation, :count).by(1)

      expect(Translation.find_by(identifier: "ara-svd")).to have_attributes(
        name: "Arabic SVD Fixture",
        note: "Fixture copyright notice",
        abbrev: "SVD",
        language: "ara",
        language_name: "Arabic"
      )
    end

    it "imports every verse and returns the count" do
      expect(import).to eq(4)

      translation = Translation.find_by(identifier: "ara-svd")
      verse = translation.verses.joins(:book).find_by(books: { book_id: "GEN" }, chapter: 1, verse_number: 1)
      expect(verse.text).to eq("Fixture verse Genesis 1:1 in Arabic.")
    end

    it "copies book names from the same-language translation with the most of them" do
      thin_reference = create(:translation, identifier: "ara-thin", language: "ara")
      create(:book_name, translation: thin_reference, book: books.fetch("GEN"), name: "Thin Genesis")

      rich_reference = create(:translation, identifier: "ara-rich", language: "ara")
      create(:book_name, translation: rich_reference, book: books.fetch("GEN"), name: "Rich Genesis")
      create(:book_name, translation: rich_reference, book: books.fetch("MAT"), name: "Rich Matthew")

      import

      translation = Translation.find_by(identifier: "ara-svd")
      mat = translation.book_names.joins(:book).find_by(books: { book_id: "MAT" })
      expect(mat.name).to eq("Rich Matthew")
    end

    it "falls back to the canonical book name when no same-language translation exists" do
      import

      translation = Translation.find_by(identifier: "ara-svd")
      gen = translation.book_names.joins(:book).find_by(books: { book_id: "GEN" })
      expect(gen.name).to eq(Book.find_by(book_id: "GEN").name)
    end

    it "raises when the canonical books have not been imported" do
      books.fetch("GEN").destroy

      expect { import }.to raise_error(described_class::MissingBooksError, /rake bible:import/)
    end

    it "is idempotent" do
      2.times { import }

      translation = Translation.find_by(identifier: "ara-svd")
      expect(Translation.where(identifier: "ara-svd").count).to eq(1)
      expect(translation.verses.count).to eq(4)
    end

    it "flushes verses in batches" do
      stub_const("#{described_class}::BATCH_SIZE", 2)

      expect(import).to eq(4)
      expect(Translation.find_by(identifier: "ara-svd").verses.count).to eq(4)
    end
  end

  describe ".import_all" do
    it "imports new files and skips identifiers already imported" do
      create(:translation, identifier: "afr", language: "afr")

      output = capture_stdout { described_class.import_all(directory: directory) }

      expect(Translation.find_by(identifier: "ara-svd").verses.count).to eq(4)
      expect(output).to include("SKIPPED (already imported): afr")
      expect(output).not_to include("Importing afr")
    end

    def capture_stdout
      original = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original
    end
  end

  describe ".import_one" do
    it "imports the file matching the given identifier" do
      described_class.import_one("ara-svd", directory: directory)

      expect(Translation.find_by(identifier: "ara-svd").verses.count).to eq(4)
    end

    it "raises when no file derives the given identifier" do
      expect { described_class.import_one("xyz-nope", directory: directory) }
        .to raise_error(described_class::UnknownTranslationError, /xyz-nope/)
    end

    it "skips without parsing anything when already imported" do
      create(:translation, identifier: "ara-svd", language: "ara")

      expect { described_class.import_one("ara-svd", directory: directory) }
        .not_to change(Verse, :count)
    end
  end
end
