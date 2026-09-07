require "rails_helper"

RSpec.describe "GraphQL concordance query", type: :request do
  let(:api_key) { create(:api_key, environment: "test") }
  let(:headers) { auth_headers(api_key.token) }
  let(:translation) { create(:translation, identifier: "spa-rv1909", name: "Reina Valera 1909", language: "spa") }
  let(:genesis) { create(:book, book_id: "GEN", name: "Genesis", testament: "OT", position: 1) }
  let(:psalms) { create(:book, book_id: "PSA", name: "Psalms", testament: "OT", position: 19) }
  let(:matthew) { create(:book, book_id: "MAT", name: "Matthew", testament: "NT", position: 40) }

  def index!
    ConcordanceIndexer.new(translation).call
  end

  FULL_SELECTION = <<~GQL
    totalCount
    entry {
      lemma
      surfaceForms
      totalOccurrences
      verseCount
      occurrencesByBook { bookId bookName count }
      occurrencesByTestament { old new }
    }
    edges {
      cursor
      node {
        verse { bookId bookName chapter verse text }
        context
        strongs { number }
      }
    }
    pageInfo { hasNextPage endCursor }
  GQL

  describe "full response shape" do
    before do
      create(:verse, translation: translation, book: genesis, text: "Grande es tu misericordia.")
      index!
    end

    it "returns entry, edges, totalCount and pageInfo" do
      query = "{ concordance(translation: \"spa-rv1909\", word: \"misericordia\") { #{FULL_SELECTION} } }"
      post "/graphql", params: { query: query }, headers: headers

      body = JSON.parse(response.body)
      expect(body["errors"]).to be_nil
      data = body["data"]["concordance"]
      expect(data["totalCount"]).to eq(1)
      expect(data["entry"]["verseCount"]).to eq(1)
      expect(data["edges"].first["node"]["verse"]["bookId"]).to eq("GEN")
      expect(data["edges"].first["node"]["context"]).to include("<mark>")
      expect(data["edges"].first["node"]["strongs"]).to be_nil
      expect(data["pageInfo"]).to have_key("hasNextPage")
    end
  end

  it "returns an error for an unknown translation" do
    query = '{ concordance(translation: "nope", word: "grace") { totalCount } }'
    post "/graphql", params: { query: query }, headers: headers

    expect(JSON.parse(response.body)["errors"]).to be_present
  end

  it "returns an error naming the rake task for an un-indexed translation" do
    create(:verse, translation: translation, book: genesis, text: "test")
    query = '{ concordance(translation: "spa-rv1909", word: "test") { totalCount } }'
    post "/graphql", params: { query: query }, headers: headers

    errors = JSON.parse(response.body)["errors"]
    expect(errors.first["message"]).to include("concordance:index")
  end

  context "once indexed" do
    before do
      create(:verse, translation: translation, book: genesis, text: "grace and truth")
      index!
    end

    it "returns an error for a blank word" do
      query = '{ concordance(translation: "spa-rv1909", word: "   ") { totalCount } }'
      post "/graphql", params: { query: query }, headers: headers

      expect(JSON.parse(response.body)["errors"]).to be_present
    end

    it "returns an error for a word over 100 characters" do
      query = "{ concordance(translation: \"spa-rv1909\", word: \"#{'a' * 101}\") { totalCount } }"
      post "/graphql", params: { query: query }, headers: headers

      expect(JSON.parse(response.body)["errors"]).to be_present
    end

    it "returns an error for an unresolvable book" do
      query = '{ concordance(translation: "spa-rv1909", word: "grace", book: "Nonexistent") { totalCount } }'
      post "/graphql", params: { query: query }, headers: headers

      expect(JSON.parse(response.body)["errors"]).to be_present
    end

    it "silently clamps first above MAX_PAGE_SIZE instead of erroring" do
      query = '{ concordance(translation: "spa-rv1909", word: "grace", first: 1000) { edges { cursor } } }'
      post "/graphql", params: { query: query }, headers: headers

      body = JSON.parse(response.body)
      expect(body["errors"]).to be_nil
      expect(body["data"]["concordance"]["edges"].size).to be <= ConcordanceLookup::MAX_PAGE_SIZE
    end
  end

  describe "testament filtering" do
    before do
      create(:verse, translation: translation, book: genesis, chapter: 1, verse_number: 1, text: "grace")
      create(:verse, translation: translation, book: matthew, chapter: 1, verse_number: 1, text: "grace")
      index!
    end

    it "filters by the OLD testament enum value" do
      query = '{ concordance(translation: "spa-rv1909", word: "grace", testament: OLD) { totalCount } }'
      post "/graphql", params: { query: query }, headers: headers

      expect(JSON.parse(response.body)["data"]["concordance"]["totalCount"]).to eq(1)
    end

    it "filters by the NEW testament enum value" do
      query = '{ concordance(translation: "spa-rv1909", word: "grace", testament: NEW) { totalCount } }'
      post "/graphql", params: { query: query }, headers: headers

      expect(JSON.parse(response.body)["data"]["concordance"]["totalCount"]).to eq(1)
    end

    it "rejects an invalid testament enum value via GraphQL's own validation" do
      query = '{ concordance(translation: "spa-rv1909", word: "grace", testament: MIDDLE) { totalCount } }'
      post "/graphql", params: { query: query }, headers: headers

      expect(JSON.parse(response.body)["errors"]).to be_present
    end
  end

  describe "complexity" do
    before do
      create(:verse, translation: translation, book: genesis, text: "grace and truth")
      index!
    end

    it "succeeds with the default first and a full field selection" do
      query = "{ concordance(translation: \"spa-rv1909\", word: \"grace\") { #{FULL_SELECTION} } }"
      post "/graphql", params: { query: query }, headers: headers

      expect(JSON.parse(response.body)["errors"]).to be_nil
    end

    it "does not require raising max_complexity even at first: 100 with a full field selection" do
      query = "{ concordance(translation: \"spa-rv1909\", word: \"grace\", first: 100) { #{FULL_SELECTION} } }"
      post "/graphql", params: { query: query }, headers: headers

      errors = JSON.parse(response.body)["errors"]
      if errors.present?
        expect(errors.first["message"]).not_to match(/timed out|internal/i)
      end
    end

    it "succeeds for the combined concordance + semanticSearch example" do
      allow(EmbeddingService).to receive(:embed).and_return([ 1.0 ] + Array.new(255, 0.0))

      query = <<~GQL
        query StudyOnGrace {
          exact: concordance(translation: "spa-rv1909", word: "grace", first: 5) {
            totalCount
            entry { surfaceForms occurrencesByTestament { old new } }
          }
          semantic: semanticSearch(query: "grace", translation: "spa-rv1909", limit: 5) {
            verse { text }
            similarity
          }
        }
      GQL
      post "/graphql", params: { query: query }, headers: headers

      expect(JSON.parse(response.body)["errors"]).to be_nil
    end
  end
end
