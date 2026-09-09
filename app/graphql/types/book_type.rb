# frozen_string_literal: true

module Types
  class BookType < Types::BaseObject
    description "A canonical book of the Bible, independent of any translation. See LocalizedBook for per-translation names."

    field :id, ID, null: false, description: "Relay global object id"
    field :book_id, String, null: false,
      description: "Canonical three-letter book id (e.g. 'GEN', 'MAT'). Use this wherever a query takes a book argument."
    field :name, String, null: false, description: "Canonical English book name (e.g. 'Genesis')"
    field :testament, String, null: false,
      description: "Either 'OT' or 'NT'. Note this is a plain String, not the Testament enum used by concordance."
    field :position, Integer, null: false,
      description: "Canonical ordering position, 1 (Genesis) through 66 (Revelation)"
  end
end
