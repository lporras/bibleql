# frozen_string_literal: true

module Types
  class BookCountType < Types::BaseObject
    field :book_id, String, null: false
    field :book_name, String, null: false, description: "Localized for the queried translation"
    field :count, Integer, null: false, description: "Number of verses in this book containing the word"
  end
end
