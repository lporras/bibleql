require "rails_helper"

RSpec.describe BiblelistImporter do
  # A tiny two-book file standing in for db/biblelist/EnglishNIVBible.xml, so the
  # real eng-niv metadata is exercised without parsing 31k verses.
  let(:directory) { Rails.root.join("spec/fixtures/biblelist") }

  def import(identifier = "eng-niv")
    described_class.new(identifier: identifier, directory: directory).import!
  end

  # eng-niv copies its book names from eng-web (see config/biblelist_translations.yml)
  def seed_reference_translation(names = { "GEN" => "Genesis", "MAT" => "Matthew" })
    reference = create(:translation, identifier: "eng-web", name: "World English Bible")
    names.each { |book_id, name| create(:book_name, translation: reference, book: books.fetch(book_id), name: name) }
    reference
  end

  let(:books) do
    BibleImporter::CANONICAL_BOOK_IDS.each_with_index.to_h do |book_id, index|
      [ book_id, create(:book, book_id: book_id, name: book_id.titleize, testament: index < 39 ? "OT" : "NT", position: index + 1) ]
    end
  end

  before { seed_reference_translation }

  describe "#initialize" do
    it "rejects an identifier that is not configured" do
      expect { described_class.new(identifier: "nope", directory: directory) }
        .to raise_error(described_class::UnknownTranslationError, /not listed/)
    end

    it "rejects a configured translation whose file is missing" do
      expect { described_class.new(identifier: "spa-nvi", directory: directory) }
        .to raise_error(described_class::MissingFileError, /not found/)
    end
  end

  describe "#import!" do
    it "creates the translation with metadata from the YAML config" do
      expect { import }.to change(Translation, :count).by(1)

      expect(Translation.find_by(identifier: "eng-niv")).to have_attributes(
        name: "New International Version",
        abbrev: "NIV",
        language: "eng",
        language_name: "English"
      )
    end

    it "prefers the configured note over the one in the XML" do
      import
      expect(Translation.find_by(identifier: "eng-niv").note).to start_with("Copyright © 1973")
    end

    it "imports every verse and returns the count" do
      expect(import).to eq(6)

      translation = Translation.find_by(identifier: "eng-niv")
      verse = translation.verses.joins(:book).find_by(books: { book_id: "GEN" }, chapter: 1, verse_number: 1)
      expect(verse.text).to eq("In the beginning God created the heavens and the earth.")
    end

    it "copies book names from the reference translation" do
      import

      translation = Translation.find_by(identifier: "eng-niv")
      mat = translation.book_names.joins(:book).find_by(books: { book_id: "MAT" })
      expect(mat.name).to eq("Matthew")
    end

    it "falls back to the canonical book name when the reference lacks one" do
      BookName.joins(:book).where(books: { book_id: "MAT" }).delete_all

      import

      translation = Translation.find_by(identifier: "eng-niv")
      mat = translation.book_names.joins(:book).find_by(books: { book_id: "MAT" })
      expect(mat.name).to eq(Book.find_by(book_id: "MAT").name)
    end

    it "is idempotent" do
      2.times { import }

      translation = Translation.find_by(identifier: "eng-niv")
      expect(Translation.where(identifier: "eng-niv").count).to eq(1)
      expect(translation.verses.count).to eq(6)
      expect(translation.book_names.count).to eq(66)
    end

    it "raises when the canonical books have not been imported" do
      books.fetch("GEN").destroy

      expect { import }.to raise_error(described_class::MissingBooksError, /rake bible:import/)
    end

    it "raises when the reference translation has no book names" do
      BookName.delete_all

      expect { import }.to raise_error(described_class::MissingReferenceError, /bible:import_one\[eng-web\]/)
    end
  end

  describe ".identifiers" do
    it "lists every configured translation" do
      expect(described_class.identifiers).to contain_exactly("eng-lsb", "eng-niv", "eng-nlt", "spa-dhh", "spa-lbla", "spa-nvi")
    end
  end
end
