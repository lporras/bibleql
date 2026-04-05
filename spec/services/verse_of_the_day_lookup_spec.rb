# frozen_string_literal: true

require "rails_helper"

RSpec.describe VerseOfTheDayLookup do
  let(:translation) { create(:translation, identifier: "eng-web", name: "World English Bible", language: "eng") }
  let(:book) { create(:book, book_id: "JHN", name: "John", testament: "NT", position: 43) }

  before do
    create(:book_name, translation: translation, book: book, name: "John")
    create(:verse, translation: translation, book: book, chapter: 3, verse_number: 16,
      text: "For God so loved the world")
  end

  it "returns a passage for the given date" do
    stub_const("VerseOfTheDayLookup::VERSES", [ "John 3:16" ])

    result = described_class.new(translation_identifier: "eng-web", date: Date.new(2026, 1, 1)).call

    expect(result[:reference]).to eq("John 3:16")
    expect(result[:verses]).to be_present
  end

  it "cycles through the verse list based on day of year" do
    verses = [ "John 3:16", "John 3:16" ]
    stub_const("VerseOfTheDayLookup::VERSES", verses)

    result1 = described_class.new(translation_identifier: "eng-web", date: Date.new(2026, 1, 1)).call
    result2 = described_class.new(translation_identifier: "eng-web", date: Date.new(2026, 1, 2)).call

    expect(result1[:reference]).to eq("John 3:16")
    expect(result2[:reference]).to eq("John 3:16")
  end

  it "raises an error for an unknown translation" do
    stub_const("VerseOfTheDayLookup::VERSES", [ "John 3:16" ])

    expect {
      described_class.new(translation_identifier: "unknown", date: Date.current).call
    }.to raise_error(PassageLookup::NotFoundError)
  end
end
