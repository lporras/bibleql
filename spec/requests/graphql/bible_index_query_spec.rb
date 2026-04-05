# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL bibleIndex query", type: :request do
  let(:api_key) { create(:api_key, environment: "test") }
  let(:headers) { auth_headers(api_key.token) }
  let(:translation) { create(:translation, identifier: "eng-web", name: "World English Bible", language: "eng") }
  let(:genesis) { create(:book, book_id: "GEN", name: "Genesis", testament: "OT", position: 1) }
  let(:matthew) { create(:book, book_id: "MAT", name: "Matthew", testament: "NT", position: 40) }

  before do
    create(:book_name, translation: translation, book: genesis, name: "Genesis")
    create(:book_name, translation: translation, book: matthew, name: "Matthew")
    create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 1, text: "In the beginning")
    create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 2, text: "The earth was formless")
    create(:verse, translation: translation, book: genesis, chapter: 2, verse_number: 1, text: "The heavens were finished")
    create(:verse, translation: translation, book: matthew, chapter: 1, verse_number: 1, text: "The book of the genealogy")
  end

  it "returns the structural hierarchy for a translation" do
    query = '{ bibleIndex(translation: "eng-web") { bookId name testament position chapterCount chapters { number verseCount } } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["bibleIndex"]
    expect(data.size).to eq(2)

    gen = data.find { |b| b["bookId"] == "GEN" }
    expect(gen["name"]).to eq("Genesis")
    expect(gen["testament"]).to eq("OT")
    expect(gen["chapterCount"]).to eq(2)
    expect(gen["chapters"].size).to eq(2)

    ch1 = gen["chapters"].find { |c| c["number"] == 1 }
    expect(ch1["verseCount"]).to eq(2)
  end

  it "uses localized book names" do
    spa = create(:translation, identifier: "spa-bes", language: "spa", name: "BES")
    create(:book_name, translation: spa, book: genesis, name: "Génesis")
    create(:verse, translation: spa, book: genesis, chapter: 1, verse_number: 1, text: "En el principio")

    query = '{ bibleIndex(translation: "spa-bes") { name } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["bibleIndex"]
    expect(data.first["name"]).to eq("Génesis")
  end

  it "returns an error for an unknown translation" do
    query = '{ bibleIndex(translation: "nope") { name } }'
    post "/graphql", params: { query: query }, headers: headers

    errors = JSON.parse(response.body)["errors"]
    expect(errors).to be_present
  end
end
