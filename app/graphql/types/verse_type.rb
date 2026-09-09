# frozen_string_literal: true

module Types
  class VerseType < Types::BaseObject
    description "A single verse in one translation"

    field :book_id, String, null: false,
      description: "Canonical three-letter book id (e.g. 'JHN', 'GEN'). Stable across every translation."
    field :book_name, String, null: false,
      description: "Book name localized to this translation (e.g. 'Juan' for Spanish). Falls back to the canonical English name when the translation has no localized name."
    field :chapter, Integer, null: false, description: "Chapter number, starting at 1"
    field :verse, Integer, null: false, description: "Verse number within the chapter, starting at 1"
    field :text, String, null: false, description: "The verse text as it appears in this translation"

    def book_id
      object.book.book_id
    end

    def book_name
      BookName.find_by(translation_id: object.translation_id, book_id: object.book_id)&.name || object.book.name
    end

    def verse
      object.verse_number
    end
  end
end
