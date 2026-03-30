# frozen_string_literal: true

module Types
  class TranslationType < Types::BaseObject
    field :id, ID, null: false
    field :identifier, String, null: false
    field :name, String, null: false
    field :language, String, null: false
    field :note, String, null: true
  end
end
