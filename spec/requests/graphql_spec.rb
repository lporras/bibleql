require "rails_helper"

RSpec.describe "GraphQL", type: :request do
  describe "POST /graphql" do
    it "returns translations" do
      create(:translation, identifier: "eng-web", name: "World English Bible")

      post "/graphql", params: { query: "{ translations { identifier name } }" }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data["translations"]).to contain_exactly(
        a_hash_including("identifier" => "eng-web", "name" => "World English Bible")
      )
    end

    it "returns books in order" do
      create(:book, book_id: "MAT", name: "Matthew", testament: "NT", position: 40)
      create(:book, book_id: "GEN", name: "Genesis", testament: "OT", position: 1)

      post "/graphql", params: { query: "{ books { bookId name testament position } }" }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)["data"]
      expect(data["books"].first["bookId"]).to eq("GEN")
      expect(data["books"].last["bookId"]).to eq("MAT")
    end
  end
end
