# frozen_string_literal: true

module Types
  class LocalizedBookType < Types::BaseObject
    field :book_id, String, null: false, description: "Unique book identifier (e.g. 'MAT', 'GEN')"
    field :name, String, null: false, description: "Localized book name for the translation"
    field :testament, String, null: false, description: "Testament: 'OT' or 'NT'"
    field :position, Integer, null: false, description: "Canonical order position (1-66)"
    field :chapter_count, Integer, null: false, description: "Number of chapters in this book for the translation"
    field :chapters, [ Types::ChapterType ], null: false, description: "All chapters in this book"
  end
end
