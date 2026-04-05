# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL translation query", type: :request do
  let(:api_key) { create(:api_key, environment: "test") }
  let(:headers) { auth_headers(api_key.token) }
  let(:translation) { create(:translation, identifier: "eng-web", name: "World English Bible", language: "eng") }
  let(:book) { create(:book, book_id: "GEN", name: "Genesis", testament: "OT", position: 1) }

  before do
    create(:book_name, translation: translation, book: book, name: "Genesis")
    create(:verse, translation: translation, book: book, chapter: 1, verse_number: 1,
      text: "In the beginning, God created the heavens and the earth.")
    create(:verse, translation: translation, book: book, chapter: 1, verse_number: 2,
      text: "The earth was formless and empty.")
    create(:verse, translation: translation, book: book, chapter: 2, verse_number: 1,
      text: "The heavens, the earth, and all their vast array were finished.")
  end

  it "returns a single translation by identifier" do
    query = '{ translation(identifier: "eng-web") { identifier name language } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["translation"]
    expect(data["identifier"]).to eq("eng-web")
    expect(data["name"]).to eq("World English Bible")
    expect(data["language"]).to eq("eng")
  end

  it "returns nested books with localized names" do
    query = '{ translation(identifier: "eng-web") { books { bookId name testament position } } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["translation"]
    books = data["books"]
    gen = books.find { |b| b["bookId"] == "GEN" }

    expect(gen["name"]).to eq("Genesis")
    expect(gen["testament"]).to eq("OT")
    expect(gen["position"]).to eq(1)
  end

  it "returns chapters nested under books" do
    query = '{ translation(identifier: "eng-web") { books { bookId chapterCount chapters { number verseCount } } } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["translation"]
    gen = data["books"].find { |b| b["bookId"] == "GEN" }

    expect(gen["chapterCount"]).to eq(2)
    expect(gen["chapters"].size).to eq(2)

    ch1 = gen["chapters"].find { |c| c["number"] == 1 }
    ch2 = gen["chapters"].find { |c| c["number"] == 2 }
    expect(ch1["verseCount"]).to eq(2)
    expect(ch2["verseCount"]).to eq(1)
  end

  it "returns an error for an unknown translation" do
    query = '{ translation(identifier: "nope") { name } }'
    post "/graphql", params: { query: query }, headers: headers

    errors = JSON.parse(response.body)["errors"]
    expect(errors).to be_present
  end
end
