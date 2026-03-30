# frozen_string_literal: true

module Types
  class BookType < Types::BaseObject
    field :id, ID, null: false
    field :book_id, String, null: false
    field :name, String, null: false
    field :testament, String, null: false
    field :position, Integer, null: false
  end
end
