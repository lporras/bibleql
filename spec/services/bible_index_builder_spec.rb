# frozen_string_literal: true

require "rails_helper"

RSpec.describe BibleIndexBuilder do
  let(:translation) { create(:translation, identifier: "eng-web", name: "World English Bible", language: "eng") }
  let(:genesis) { create(:book, book_id: "GEN", name: "Genesis", testament: "OT", position: 1) }
  let(:exodus) { create(:book, book_id: "EXO", name: "Exodus", testament: "OT", position: 2) }

  before do
    create(:book_name, translation: translation, book: genesis, name: "Genesis")
    create(:book_name, translation: translation, book: exodus, name: "Exodus")
    create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 1, text: "In the beginning")
    create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 2, text: "The earth was formless")
    create(:verse, translation: translation, book: genesis, chapter: 2, verse_number: 1, text: "Heavens finished")
    create(:verse, translation: translation, book: exodus, chapter: 1, verse_number: 1, text: "Now these are the names")
  end

  it "returns books in canonical order" do
    result = described_class.new(translation: translation).call

    expect(result.size).to eq(2)
    expect(result.first.book_id).to eq("GEN")
    expect(result.last.book_id).to eq("EXO")
  end

  it "includes chapter counts" do
    result = described_class.new(translation: translation).call

    gen = result.find { |b| b.book_id == "GEN" }
    expect(gen.chapter_count).to eq(2)
  end

  it "includes verse counts per chapter" do
    result = described_class.new(translation: translation).call

    gen = result.find { |b| b.book_id == "GEN" }
    ch1 = gen.chapters.find { |c| c.number == 1 }
    ch2 = gen.chapters.find { |c| c.number == 2 }

    expect(ch1.verse_count).to eq(2)
    expect(ch2.verse_count).to eq(1)
  end

  it "uses localized book names" do
    result = described_class.new(translation: translation).call

    expect(result.first.name).to eq("Genesis")
  end
end
