# frozen_string_literal: true

module Types
  class ConcordanceConnectionType < Types::BaseObject
    description "A page of concordance occurrences plus translation-wide aggregates for the word"

    PageInfoStruct = Struct.new(:has_next_page, :end_cursor, keyword_init: true)

    field :entry, Types::ConcordanceEntryType, null: false,
      description: "Aggregate counts for the word across the whole translation — unaffected by paging or by the book/testament filters"
    field :total_count, Integer, null: false,
      description: "Total occurrences matching the current filters, across all pages"
    field :edges, [ Types::ConcordanceEdgeType ], null: false,
      description: "This page of occurrences, in canonical order (Genesis → Revelation, then chapter, then verse). Never ranked by relevance."
    field :page_info, Types::ConcordancePageInfoType, null: false,
      description: "Cursor and flag for fetching the next page"

    def page_info
      PageInfoStruct.new(has_next_page: object.has_next_page, end_cursor: object.end_cursor)
    end
  end
end
