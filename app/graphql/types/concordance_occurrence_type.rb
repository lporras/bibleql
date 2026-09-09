# frozen_string_literal: true

module Types
  class ConcordanceOccurrenceType < Types::BaseObject
    description "A single occurrence of a word in one verse, with surrounding context"

    field :verse, Types::VerseType, null: false, description: "The verse containing the word"
    field :context, String, null: false, resolver_method: :highlighted_context,
      description: "Keyword-in-context snippet. Contains <mark> HTML tags around the matched term — sanitize before rendering as HTML."
    field :strongs, Types::StrongsEntryType, null: true,
      description: "Null unless the translation has Strong's number tagging. See translation.hasStrongsTagging (Phase 2, always false today)."

    def highlighted_context = object.context

    def strongs = nil
  end
end
