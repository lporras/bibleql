require "rails_helper"

RSpec.describe "GraphQL concordanceIndex query", type: :request do
  let(:api_key) { create(:api_key, environment: "test") }
  let(:headers) { auth_headers(api_key.token) }
  let(:translation) { create(:translation, identifier: "spa-rv1909", name: "Reina Valera 1909", language: "spa") }
  let(:genesis) { create(:book, book_id: "GEN", name: "Genesis", testament: "OT", position: 1) }

  def index!
    ConcordanceIndexer.new(translation).call
  end

  it "returns alphabetical word entries with counts" do
    create(:verse, translation: translation, book: genesis, text: "misericordia y gracia")
    index!

    query = '{ concordanceIndex(translation: "spa-rv1909") { lemma verseCount totalOccurrences } }'
    post "/graphql", params: { query: query }, headers: headers

    body = JSON.parse(response.body)
    expect(body["errors"]).to be_nil
    lemmas = body["data"]["concordanceIndex"].map { |e| e["lemma"] }
    expect(lemmas).to include("misericordi", "graci")
  end

  it "filters by prefix" do
    create(:verse, translation: translation, book: genesis, text: "misericordia y gracia")
    index!

    query = '{ concordanceIndex(translation: "spa-rv1909", prefix: "mis") { lemma } }'
    post "/graphql", params: { query: query }, headers: headers

    lemmas = JSON.parse(response.body)["data"]["concordanceIndex"].map { |e| e["lemma"] }
    expect(lemmas).to all(start_with("mis"))
  end

  it "returns an error for an unknown translation" do
    query = '{ concordanceIndex(translation: "nope") { lemma } }'
    post "/graphql", params: { query: query }, headers: headers

    expect(JSON.parse(response.body)["errors"]).to be_present
  end

  it "returns an error naming the rake task for an un-indexed translation" do
    translation # create the translation without indexing it
    query = '{ concordanceIndex(translation: "spa-rv1909") { lemma } }'
    post "/graphql", params: { query: query }, headers: headers

    errors = JSON.parse(response.body)["errors"]
    expect(errors.first["message"]).to include("concordance:index")
  end
end
