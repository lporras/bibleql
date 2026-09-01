require "rails_helper"

RSpec.describe BiblelistFormat::Parser do
  let(:fixture) { Rails.root.join("spec/fixtures/biblelist/EnglishNIVBible.xml") }

  def parser = described_class.new(File.open(fixture))

  describe "#valid?" do
    it "recognizes the biblelist format" do
      expect(parser.valid?).to be_truthy
    end

    it "rejects an open-bibles USFX file" do
      usfx = described_class.new(File.open(Rails.root.join("db/open-bibles/eng-web.usfx.xml")))
      expect(usfx.valid?).to be_falsey
    end
  end

  describe "#bible_attributes" do
    it "returns the root element's attributes" do
      expect(parser.bible_attributes).to include(
        "translation" => "English NIV",
        "info" => "Fixture copyright notice"
      )
    end

    it "rewinds the io so the same parser can then read verses" do
      instance = parser
      instance.bible_attributes

      verses = []
      instance.each_verse { |verse| verses << verse }
      expect(verses.size).to eq(6)
    end
  end

  describe "#each_book" do
    it "maps ordinal book numbers to canonical book ids" do
      books = []
      parser.each_book { |book| books << book }

      expect(books.map(&:id)).to eq(%w[GEN MAT])
      expect(books.map(&:num)).to eq([ 1, 40 ])
    end
  end

  describe "#each_verse" do
    it "yields every verse with its book, chapter and number" do
      verses = []
      parser.each_verse { |verse| verses << verse }

      expect(verses.size).to eq(6)
      expect(verses.first).to have_attributes(
        book_id: "GEN",
        chapter_num: 1,
        num: 1,
        text: "In the beginning God created the heavens and the earth."
      )
      expect(verses.last).to have_attributes(book_id: "MAT", chapter_num: 28, num: 20)
    end

    it "tracks chapters within a book" do
      chapters = []
      parser.each_verse { |verse| chapters << [ verse.book_id, verse.chapter_num ] }

      expect(chapters.uniq).to eq([ [ "GEN", 1 ], [ "GEN", 2 ], [ "MAT", 28 ] ])
    end
  end
end
