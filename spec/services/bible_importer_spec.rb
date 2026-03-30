require "rails_helper"

RSpec.describe BibleImporter do
  let(:file_path) { Rails.root.join("db/open-bibles/eng-web.usfx.xml").to_s }

  describe "#initialize" do
    it "extracts identifier from filename" do
      importer = described_class.new(file_path: file_path)
      expect(importer.identifier).to eq("eng-web")
    end
  end

  describe "#import!" do
    it "creates a translation" do
      expect {
        described_class.new(file_path: file_path).import!
      }.to change(Translation, :count).by(1)

      translation = Translation.find_by(identifier: "eng-web")
      expect(translation.language).to eq("eng")
    end

    it "creates 66 canonical books" do
      described_class.new(file_path: file_path).import!
      expect(Book.count).to eq(66)
    end

    it "creates book names for the translation" do
      described_class.new(file_path: file_path).import!
      translation = Translation.find_by(identifier: "eng-web")
      expect(translation.book_names.count).to eq(66)
    end

    it "imports verses" do
      described_class.new(file_path: file_path).import!
      translation = Translation.find_by(identifier: "eng-web")
      expect(translation.verses.count).to be > 30_000
    end

    it "is idempotent" do
      2.times { described_class.new(file_path: file_path).import! }
      expect(Translation.where(identifier: "eng-web").count).to eq(1)
    end

    it "stores localized book names" do
      spa_path = Rails.root.join("db/open-bibles/spa-bes.usfx.xml").to_s
      described_class.new(file_path: spa_path).import!

      translation = Translation.find_by(identifier: "spa-bes")
      mat_name = translation.book_names.joins(:book).find_by(books: { book_id: "MAT" })
      expect(mat_name.name).to eq("Mateo")
    end
  end
end
