# frozen_string_literal: true

module Types
  class PassageType < Types::BaseObject
    description "A resolved range of verses, returned by the passage and verseOfTheDay queries"

    field :reference, String, null: false,
      description: "The reference in normalized form. Localized input keeps its own book name (e.g. 'Juan 3:16')."
    field :verses, [ Types::VerseType ], null: false,
      description: "Every verse the reference resolved to, in canonical order"
    field :text, String, null: false,
      description: "All verse texts joined with newlines — convenient for display when you do not need each verse separately"
    field :translation_id, String, null: false,
      description: "Identifier of the translation this passage came from (e.g. 'eng-web')"
    field :translation_name, String, null: false,
      description: "Full name of the translation (e.g. 'World English Bible')"
    field :translation_note, String, null: true,
      description: "Licensing or attribution note for the translation (e.g. 'Public Domain', 'CC BY 4.0')"
  end
end
