# frozen_string_literal: true

module Types
  class ConcordanceOccurrenceType < Types::BaseObject
    field :verse, Types::VerseType, null: false
    field :context, String, null: false,
      description: "Keyword-in-context snippet. Contains <mark> HTML tags around the matched term — sanitize before rendering as HTML."
    field :strongs, Types::StrongsEntryType, null: true,
      description: "Null unless the translation has Strong's number tagging. See translation.hasStrongsTagging (Phase 2, always false today)."

    def strongs = nil
  end
end
