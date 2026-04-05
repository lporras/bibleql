# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL languages query", type: :request do
  let(:api_key) { create(:api_key, environment: "test") }
  let(:headers) { auth_headers(api_key.token) }

  before do
    create(:translation, identifier: "eng-web", language: "eng", name: "World English Bible")
    create(:translation, identifier: "eng-kjv", language: "eng", name: "King James Version")
    create(:translation, identifier: "spa-bes", language: "spa", name: "Biblia en Espanol")
  end

  it "returns all distinct languages with translation counts" do
    query = '{ languages { code translationCount } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["languages"]
    eng = data.find { |l| l["code"] == "eng" }
    spa = data.find { |l| l["code"] == "spa" }

    expect(eng["translationCount"]).to eq(2)
    expect(spa["translationCount"]).to eq(1)
  end

  it "returns nested translations for each language" do
    query = '{ languages { code translations { identifier name } } }'
    post "/graphql", params: { query: query }, headers: headers

    data = JSON.parse(response.body)["data"]["languages"]
    eng = data.find { |l| l["code"] == "eng" }

    expect(eng["translations"].size).to eq(2)
    identifiers = eng["translations"].map { |t| t["identifier"] }
    expect(identifiers).to include("eng-web", "eng-kjv")
  end
end
