# frozen_string_literal: true

module Types
  class StrongsEntryType < Types::BaseObject
    description "Placeholder for Phase 2 Strong's number tagging — not yet populated"
    field :number, String, null: false, description: "e.g. H2617, G26 (Phase 2)"
  end
end
