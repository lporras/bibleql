# frozen_string_literal: true

module Types
  class TestamentCountType < Types::BaseObject
    description "Occurrence counts split across the two testaments"

    field :old, Integer, null: false, description: "Verses containing the word in the Old Testament"
    field :new, Integer, null: false, description: "Verses containing the word in the New Testament"
  end
end
