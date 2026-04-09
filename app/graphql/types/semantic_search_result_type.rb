# frozen_string_literal: true

module Types
  class SemanticSearchResultType < Types::BaseObject
    field :verse, Types::VerseType, null: false
    field :similarity, Float, null: false
  end
end
