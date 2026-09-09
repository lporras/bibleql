# frozen_string_literal: true

module Types
  class TranslationType < Types::BaseObject
    description "A Bible translation available through the API"

    field :id, ID, null: false, description: "Relay global object id"
    field :identifier, String, null: false,
      description: "Stable identifier used by every query's translation argument (e.g. 'eng-web', 'spa-rv1909')"
    field :name, String, null: false, description: "Full translation name (e.g. 'World English Bible')"
    field :language, String, null: false, description: "Language code (e.g. 'eng', 'spa')"
    field :abbrev, String, null: true, description: "Common abbreviation (e.g. 'WEB', 'KJV')"
    field :language_name, String, null: true, description: "Human-readable language (e.g. 'English (UK)')"
    field :note, String, null: true,
      description: "Licensing or attribution note (e.g. 'Public Domain', 'CC BY 4.0')"
    field :books, [ Types::LocalizedBookType ], null: false,
      description: "All books available in this translation with localized names"
    field :has_stemming, Boolean, null: false,
      description: "Whether concordance queries apply linguistic stemming for this translation. When false, only exact word forms match."
    field :has_strongs_tagging, Boolean, null: false,
      description: "Whether verses in this translation carry Strong's number annotations (Phase 2 — always false today)"
    field :concordance_indexed_at, GraphQL::Types::ISO8601DateTime, null: true,
      description: "When the concordance index was last built. Null means concordance queries will error until `rake concordance:index` runs."

    def books
      BibleIndexBuilder.new(translation: object).call
    end

    def has_strongs_tagging = false
  end
end
