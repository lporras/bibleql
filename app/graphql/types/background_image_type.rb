# frozen_string_literal: true

module Types
  class BackgroundImageType < Types::BaseObject
    description "A background photo from Unsplash. Display it with \"Photo by <photographer> on Unsplash\", " \
      "both linked, and call trackImageDownload when the user actually uses it."

    field :id, ID, null: false, description: "Unsplash photo id"
    field :width, Integer, null: true, description: "Original width in pixels"
    field :height, Integer, null: true, description: "Original height in pixels"
    field :color, String, null: true, description: "Dominant color as a hex string, useful as a loading placeholder"
    field :blur_hash, String, null: true, description: "BlurHash string for a blurred loading placeholder"
    field :alt_description, String, null: true, description: "Short description of the photo, for alt text"
    field :urls, Types::BackgroundImageUrlsType, null: false, description: "CDN URLs in several sizes"
    field :photographer, Types::BackgroundImagePhotographerType, null: false, description: "Who to credit"
    field :unsplash_url, String, null: true,
      description: "The photo's page on Unsplash, with referral parameters; link \"Unsplash\" in the credit to it"
    field :download_location, String, null: true,
      description: "Unsplash's download-tracking URL for this photo. Informational: do not call it directly, " \
        "use the trackImageDownload mutation"
  end
end
