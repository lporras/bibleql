# frozen_string_literal: true

module Types
  class ConcordanceConnectionType < Types::BaseObject
    PageInfoStruct = Struct.new(:has_next_page, :end_cursor, keyword_init: true)

    field :entry, Types::ConcordanceEntryType, null: false
    field :total_count, Integer, null: false
    field :edges, [ Types::ConcordanceEdgeType ], null: false
    field :page_info, Types::ConcordancePageInfoType, null: false

    def page_info
      PageInfoStruct.new(has_next_page: object.has_next_page, end_cursor: object.end_cursor)
    end
  end
end
