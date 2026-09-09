# frozen_string_literal: true

module Types
  class ConcordanceEntryType < Types::BaseObject
    description "Aggregate information about a word across a translation"

    field :lemma, String, null: false,
      description: "Normalized stem from the translation's text search dictionary. May look garbled (e.g. 'misericordi') — use surfaceForms for display."
    field :surface_forms, [ String ], null: false,
      description: "Up to 10 actual word forms found in the text, most frequent first (e.g. amor, amores, amoroso). Sampled, not exhaustive."
    field :total_occurrences, Integer, null: false,
      description: "Raw token matches; can exceed verseCount if the word repeats within a single verse."
    field :verse_count, Integer, null: false, description: "Number of distinct verses containing the word"
    field :occurrences_by_book, [ Types::BookCountType ], null: false,
      description: "Per-book distribution in canonical order. Books with no occurrences are omitted."
    field :occurrences_by_testament, Types::TestamentCountType, null: false,
      description: "Occurrence totals split across the Old and New Testaments"
  end
end
