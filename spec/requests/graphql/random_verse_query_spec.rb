# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL randomVerse query", type: :request do
  let(:api_key) { create(:api_key, environment: "test") }
  let(:headers) { auth_headers(api_key.token) }
  let(:translation) { create(:translation, identifier: "eng-web", name: "World English Bible", language: "eng") }
  let(:ot_book) { create(:book, book_id: "GEN", name: "Genesis", testament: "OT", position: 1) }
  let(:nt_book) { create(:book, book_id: "MAT", name: "Matthew", testament: "NT", position: 40) }

  before do
    create(:book_name, translation: translation, book: ot_book, name: "Genesis")
    create(:book_name, translation: translation, book: nt_book, name: "Matthew")
    create(:verse, translation: translation, book: ot_book, chapter: 1, verse_number: 1,
      text: "In the beginning, God created the heavens and the earth.")
    create(:verse, translation: translation, book: nt_book, chapter: 1, verse_number: 1,
      text: "The book of the genealogy of Jesus Christ.")
  end

  it "returns a random verse from the translation" do
    query = '{ randomVerse { bookId chapter verse text } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["randomVerse"]
    expect(data["bookId"]).to be_in(%w[GEN MAT])
    expect(data["text"]).to be_present
  end

  it "filters by Old Testament" do
    query = '{ randomVerse(testament: "OT") { bookId text } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["randomVerse"]
    expect(data["bookId"]).to eq("GEN")
  end

  it "filters by New Testament" do
    query = '{ randomVerse(testament: "NT") { bookId text } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["randomVerse"]
    expect(data["bookId"]).to eq("MAT")
  end

  it "filters by specific books" do
    query = '{ randomVerse(books: "MAT") { bookId text } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["randomVerse"]
    expect(data["bookId"]).to eq("MAT")
  end

  it "filters by multiple comma-separated books" do
    exo = create(:book, book_id: "EXO", name: "Exodus", testament: "OT", position: 2)
    create(:book_name, translation: translation, book: exo, name: "Exodus")
    create(:verse, translation: translation, book: exo, chapter: 1, verse_number: 1,
      text: "Now these are the names of the sons of Israel.")

    query = '{ randomVerse(books: "GEN,EXO") { bookId text } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["randomVerse"]
    expect(data["bookId"]).to be_in(%w[GEN EXO])
  end

  it "returns error for invalid testament value" do
    query = '{ randomVerse(testament: "INVALID") { text } }'
    post "/graphql", params: { query: query }, headers: headers

    errors = JSON.parse(response.body)["errors"]
    expect(errors).to be_present
    expect(errors.first["message"]).to include("OT")
  end
end
