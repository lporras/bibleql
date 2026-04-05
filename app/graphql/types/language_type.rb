# frozen_string_literal: true

module Types
  class LanguageType < Types::BaseObject
    field :code, String, null: false, description: "Language code (e.g. 'eng', 'spa')"
    field :translation_count, Integer, null: false, description: "Number of translations available in this language"
    field :translations, [ Types::TranslationType ], null: false, description: "All translations in this language"

    def translations
      Translation.where(language: object.code).order(:identifier)
    end
  end
end
