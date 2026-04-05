# frozen_string_literal: true

module Types
  class ChapterType < Types::BaseObject
    field :number, Integer, null: false, description: "Chapter number"
    field :verse_count, Integer, null: false, description: "Number of verses in this chapter"
    field :verses, [ Types::VerseType ], null: false, description: "All verses in this chapter"

    def verses
      Verse.includes(:book)
        .where(translation_id: object.translation_id, book_id: object.book_id, chapter: object.number)
        .order(:verse_number)
    end
  end
end
