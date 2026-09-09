# frozen_string_literal: true

module Types
  class ConcordancePageInfoType < Types::BaseObject
    description "Paging state for a concordance result"

    field :has_next_page, Boolean, null: false,
      description: "True when more occurrences remain beyond this page"
    field :end_cursor, String, null: true,
      description: "Cursor of the last occurrence on this page. Pass it as `after` to fetch the next page. Null when the page is empty."
  end
end
