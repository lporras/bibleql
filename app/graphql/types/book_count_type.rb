# frozen_string_literal: true

module Types
  class BookCountType < Types::BaseObject
    description "Occurrence count for one book in a concordance result"

    field :book_id, String, null: false,
      description: "Canonical three-letter book id (e.g. 'PSA')"
    field :book_name, String, null: false, description: "Localized for the queried translation"
    field :count, Integer, null: false, description: "Number of verses in this book containing the word"
  end
end
