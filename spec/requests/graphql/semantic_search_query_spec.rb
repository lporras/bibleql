require "rails_helper"

RSpec.describe "GraphQL semanticSearch query", type: :request do
  let(:api_key) { create(:api_key, environment: "test") }
  let(:headers) { auth_headers(api_key.token) }
  let(:translation) { create(:translation, identifier: "spa-rv1909", name: "Reina Valera 1909", language: "spa") }
  let(:book) { create(:book, book_id: "1CO", name: "1 Corinthians", testament: "NT", position: 46) }

  # Simple distinct vectors for predictable similarity ordering
  let(:query_vector) { [ 1.0 ] + Array.new(255, 0.0) }
  let(:close_vector) { [ 0.9, 0.1 ] + Array.new(254, 0.0) }
  let(:far_vector) { [ 0.1, 0.9 ] + Array.new(254, 0.0) }

  before do
    create(:book_name, translation: translation, book: book, name: "1 Corintios")
    create(:verse, translation: translation, book: book, chapter: 13, verse_number: 13,
      text: "Y ahora permanecen la fe, la esperanza y el amor.",
      embedding: close_vector)
    create(:verse, translation: translation, book: book, chapter: 1, verse_number: 1,
      text: "Pablo, llamado a ser apóstol de Jesucristo.",
      embedding: far_vector)
    create(:verse, translation: translation, book: book, chapter: 2, verse_number: 1,
      text: "Así que, hermanos, cuando fui a vosotros.",
      embedding: nil)

    allow(EmbeddingService).to receive(:embed).and_return(query_vector)
  end

  it "returns verses sorted by semantic similarity" do
    query = <<~GQL
      {
        semanticSearch(query: "fe y esperanza", limit: 10) {
          verse { bookName chapter verse text }
          similarity
        }
      }
    GQL
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["semanticSearch"]
    expect(data.length).to eq(2)
    expect(data.first["verse"]["text"]).to include("fe, la esperanza")
    expect(data.first["similarity"]).to be > data.second["similarity"]
  end

  it "excludes verses without embeddings" do
    query = '{ semanticSearch(query: "test") { verse { text } } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["semanticSearch"]
    texts = data.map { |r| r["verse"]["text"] }
    expect(texts).not_to include("Así que, hermanos, cuando fui a vosotros.")
  end

  it "respects the limit argument" do
    query = '{ semanticSearch(query: "test", limit: 1) { verse { text } } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["semanticSearch"]
    expect(data.length).to eq(1)
  end

  it "returns an error for unknown translations" do
    query = '{ semanticSearch(query: "test", translation: "nope") { verse { text } } }'
    post "/graphql", params: { query: query }, headers: headers

    errors = JSON.parse(response.body)["errors"]
    expect(errors).to be_present
  end

  it "returns an empty array when no verses have embeddings" do
    other_translation = create(:translation, identifier: "eng-web", name: "WEB", language: "eng")
    query = "{ semanticSearch(query: \"test\", translation: \"eng-web\") { verse { text } } }"
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["semanticSearch"]
    expect(data).to eq([])
  end
end
