# frozen_string_literal: true

module Types
  class PassageType < Types::BaseObject
    field :reference, String, null: false
    field :verses, [Types::VerseType], null: false
    field :text, String, null: false
    field :translation_id, String, null: false
    field :translation_name, String, null: false
    field :translation_note, String, null: true
  end
end
