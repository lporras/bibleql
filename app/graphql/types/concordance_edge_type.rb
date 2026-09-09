# frozen_string_literal: true

module Types
  class ConcordanceEdgeType < Types::BaseObject
    description "One occurrence together with its pagination cursor"

    field :node, Types::ConcordanceOccurrenceType, null: false, description: "The occurrence itself"
    field :cursor, String, null: false,
      description: "Opaque cursor for this position. Pass it as the concordance `after` argument to continue from here."
  end
end
