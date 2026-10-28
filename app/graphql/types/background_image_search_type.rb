# frozen_string_literal: true

module Types
  class BackgroundImageSearchType < Types::BaseObject
    description "One page of background image search results"

    field :images, [ Types::BackgroundImageType ], null: false,
      description: "Photos on this page; empty when errorCode is set"
    field :page, Integer, null: false, description: "Page number returned"
    field :total_pages, Integer, null: false, description: "Total pages available for this query"
    field :has_more, Boolean, null: false, description: "Whether a later page exists"
    field :error_code, Types::BackgroundImageErrorCodeEnum, null: true,
      description: "Set when the search could not be completed; images is then empty"

    def has_more
      object[:page] < object[:total_pages]
    end
  end
end
