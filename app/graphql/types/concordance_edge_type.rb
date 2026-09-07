# frozen_string_literal: true

module Types
  class ConcordanceEdgeType < Types::BaseObject
    field :node, Types::ConcordanceOccurrenceType, null: false
    field :cursor, String, null: false
  end
end
