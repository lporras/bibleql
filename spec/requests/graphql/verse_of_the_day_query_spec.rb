# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL verseOfTheDay query", type: :request do
  let(:api_key) { create(:api_key, environment: "test") }
  let(:headers) { auth_headers(api_key.token) }
  let(:translation) { create(:translation, identifier: "eng-web", name: "World English Bible", language: "eng") }
  let(:book) { create(:book, book_id: "JHN", name: "John", testament: "NT", position: 43) }

  before do
    create(:book_name, translation: translation, book: book, name: "John")
    create(:verse, translation: translation, book: book, chapter: 3, verse_number: 16,
      text: "For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life.")
  end

  it "returns the verse of the day for today" do
    # Stub the VOTD list so index 0 maps to our test verse
    stub_const("VerseOfTheDayLookup::VERSES", [ "John 3:16" ])

    query = '{ verseOfTheDay { reference text translationName } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["verseOfTheDay"]
    expect(data["reference"]).to eq("John 3:16")
    expect(data["text"]).to include("For God so loved")
    expect(data["translationName"]).to eq("World English Bible")
  end

  it "accepts a specific date" do
    stub_const("VerseOfTheDayLookup::VERSES", [ "John 3:16" ])

    query = '{ verseOfTheDay(date: "2026-12-25") { reference text } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["verseOfTheDay"]
    expect(data["reference"]).to eq("John 3:16")
    expect(data["text"]).to include("For God so loved")
  end

  it "accepts a translation argument" do
    spa = create(:translation, identifier: "spa-bes", language: "spa", name: "BES")
    create(:book_name, translation: spa, book: book, name: "Juan")
    create(:verse, translation: spa, book: book, chapter: 3, verse_number: 16,
      text: "Porque de tal manera amó Dios al mundo")

    stub_const("VerseOfTheDayLookup::VERSES", [ "John 3:16" ])

    query = '{ verseOfTheDay(translation: "spa-bes") { reference text translationName } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["verseOfTheDay"]
    expect(data["text"]).to include("amó Dios")
  end
end
