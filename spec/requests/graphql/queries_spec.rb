require "rails_helper"

RSpec.describe "GraphQL Queries", type: :request do
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
    create(:verse, translation: translation, book: book, chapter: 1, verse_number: 3,
      text: "God said, \"Let there be light,\" and there was light.")
  end

  describe "chapter query" do
    it "returns all verses in a chapter" do
      query = '{ chapter(book: "GEN", chapter: 1) { bookId chapter verse text } }'
      post "/graphql", params: { query: query }, headers: headers

      data = JSON.parse(response.body)["data"]["chapter"]
      expect(data.size).to eq(3)
      expect(data.first["verse"]).to eq(1)
      expect(data.last["verse"]).to eq(3)
    end

    it "accepts localized book names" do
      spa = create(:translation, identifier: "spa-bes", language: "spa", name: "BES")
      create(:book_name, translation: spa, book: book, name: "Génesis")
      create(:verse, translation: spa, book: book, chapter: 1, verse_number: 1, text: "En el principio creó Dios los cielos y la tierra.")

      query = '{ chapter(translation: "spa-bes", book: "Génesis", chapter: 1) { text } }'
      post "/graphql", params: { query: query }, headers: headers

      data = JSON.parse(response.body)["data"]["chapter"]
      expect(data.size).to eq(1)
      expect(data.first["text"]).to include("principio")
    end
  end

  describe "verse query" do
    it "returns a single verse" do
      query = '{ verse(book: "GEN", chapter: 1, verse: 1) { bookId bookName chapter verse text } }'
      post "/graphql", params: { query: query }, headers: headers

      data = JSON.parse(response.body)["data"]["verse"]
      expect(data["bookId"]).to eq("GEN")
      expect(data["bookName"]).to eq("Genesis")
      expect(data["chapter"]).to eq(1)
      expect(data["verse"]).to eq(1)
      expect(data["text"]).to include("In the beginning")
    end
  end

  describe "search query" do
    it "finds verses by text content" do
      query = '{ search(query: "light") { bookId chapter verse text } }'
      post "/graphql", params: { query: query }, headers: headers

      data = JSON.parse(response.body)["data"]["search"]
      expect(data.size).to eq(1)
      expect(data.first["text"]).to include("light")
    end

    it "is case-insensitive" do
      query = '{ search(query: "BEGINNING") { text } }'
      post "/graphql", params: { query: query }, headers: headers

      data = JSON.parse(response.body)["data"]["search"]
      expect(data.size).to eq(1)
    end

    it "respects the limit" do
      query = '{ search(query: "the", limit: 2) { text } }'
      post "/graphql", params: { query: query }, headers: headers

      data = JSON.parse(response.body)["data"]["search"]
      expect(data.size).to be <= 2
    end
  end

  describe "error handling" do
    it "returns a GraphQL error for unknown translations" do
      query = '{ passage(translation: "nope", reference: "John 3:16") { text } }'
      post "/graphql", params: { query: query }, headers: headers

      errors = JSON.parse(response.body)["errors"]
      expect(errors).to be_present
      expect(errors.first["message"]).to include("Translation")
    end

    it "returns a GraphQL error for unknown books" do
      query = '{ passage(reference: "FakeBook 1:1") { text } }'
      post "/graphql", params: { query: query }, headers: headers

      errors = JSON.parse(response.body)["errors"]
      expect(errors).to be_present
    end
  end
end
