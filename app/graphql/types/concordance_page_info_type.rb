# frozen_string_literal: true

module Types
  class ConcordancePageInfoType < Types::BaseObject
    field :has_next_page, Boolean, null: false
    field :end_cursor, String, null: true
  end
end
