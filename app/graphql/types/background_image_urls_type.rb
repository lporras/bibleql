# frozen_string_literal: true

module Types
  class BackgroundImageUrlsType < Types::BaseObject
    description "Unsplash CDN URLs for one photo, in several sizes. Hotlink these directly; do not rehost the image."

    field :raw, String, null: true, description: "Original image, unprocessed"
    field :full, String, null: true, description: "Full resolution, compressed JPEG"
    field :regular, String, null: true, description: "1080px wide; suitable as a background"
    field :small, String, null: true, description: "400px wide"
    field :thumb, String, null: true, description: "200px wide; suitable for search result grids"
  end
end
