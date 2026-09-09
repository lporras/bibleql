# frozen_string_literal: true

module Types
  class SemanticSearchResultType < Types::BaseObject
    description "A verse matched by meaning rather than by wording, with its similarity score"

    field :verse, Types::VerseType, null: false, description: "The matched verse"
    field :similarity, Float, null: false,
      description: "Cosine similarity to the query, from 0.0 to 1.0 — higher is closer in meaning. Results are ordered by this value, descending."
  end
end
