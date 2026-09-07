# frozen_string_literal: true

module Types
  class ConcordanceIndexEntryType < Types::BaseObject
    description "One entry in a translation's alphabetical word frequency index"
    field :lemma, String, null: false
    field :verse_count, Integer, null: false, description: "Distinct verses containing this word"
    field :total_occurrences, Integer, null: false, description: "Total raw token count across the translation"
  end
end
