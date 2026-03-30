# frozen_string_literal: true

module Types
  class VerseType < Types::BaseObject
    field :book_id, String, null: false
    field :book_name, String, null: false
    field :chapter, Integer, null: false
    field :verse, Integer, null: false
    field :text, String, null: false

    def book_id
      object.book.book_id
    end

    def book_name
      object.book.name
    end

    def verse
      object.verse_number
    end
  end
end
