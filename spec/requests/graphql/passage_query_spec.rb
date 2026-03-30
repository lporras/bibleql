require "rails_helper"

RSpec.describe "Passage Query", type: :request do
  let(:translation) { create(:translation, identifier: "eng-web", name: "World English Bible", language: "eng") }
  let(:book) { create(:book, book_id: "JHN", name: "John", testament: "NT", position: 43) }

  before do
    create(:book_name, translation: translation, book: book, name: "John")
    create(:verse, translation: translation, book: book, chapter: 3, verse_number: 16,
      text: "For God so loved the world, that he gave his only born Son, that whoever believes in him should not perish, but have eternal life.")
  end

  it "returns a passage by reference" do
    query = <<~GQL
      {
        passage(reference: "John 3:16") {
          reference
          text
          translationId
          translationName
          translationNote
          verses {
            bookId
            bookName
            chapter
            verse
            text
          }
        }
      }
    GQL

    post "/graphql", params: { query: query }

    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body)["data"]["passage"]

    expect(data["reference"]).to eq("John 3:16")
    expect(data["translationId"]).to eq("eng-web")
    expect(data["translationName"]).to eq("World English Bible")
    expect(data["verses"].size).to eq(1)
    expect(data["verses"].first["bookId"]).to eq("JHN")
    expect(data["verses"].first["bookName"]).to eq("John")
    expect(data["verses"].first["chapter"]).to eq(3)
    expect(data["verses"].first["verse"]).to eq(16)
    expect(data["verses"].first["text"]).to include("For God so loved")
  end

  it "supports localized book names" do
    spa = create(:translation, identifier: "spa-bes", name: "Biblia en Español", language: "spa")
    create(:book_name, translation: spa, book: book, name: "Juan")
    create(:verse, translation: spa, book: book, chapter: 3, verse_number: 16,
      text: "Porque de tal manera amó Dios al mundo, que ha dado a su Hijo unigénito.")

    query = <<~GQL
      {
        passage(translation: "spa-bes", reference: "Juan 3:16") {
          reference
          translationId
          verses { bookId text }
        }
      }
    GQL

    post "/graphql", params: { query: query }

    data = JSON.parse(response.body)["data"]["passage"]
    expect(data["reference"]).to include("Juan")
    expect(data["translationId"]).to eq("spa-bes")
    expect(data["verses"].first["text"]).to include("amó Dios")
  end
end
