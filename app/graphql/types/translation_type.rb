# frozen_string_literal: true

module Types
  class TranslationType < Types::BaseObject
    field :id, ID, null: false
    field :identifier, String, null: false
    field :name, String, null: false
    field :language, String, null: false
    field :note, String, null: true
    field :books, [ Types::LocalizedBookType ], null: false,
      description: "All books available in this translation with localized names"

    def books
      BibleIndexBuilder.new(translation: object).call
    end
  end
end
