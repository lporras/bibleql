# frozen_string_literal: true

module Mutations
  class TrackImageDownload < BaseMutation
    description "Reports that the user used a background image (set it as a background or exported it). " \
      "Required by Unsplash's API guidelines; not needed when an image is merely displayed in search results."

    IMAGE_ID_FORMAT = /\A[\w-]{1,32}\z/

    argument :image_id, ID, required: true, description: "The BackgroundImage id that was used"

    field :queued, Boolean, null: false, description: "Whether the download ping was queued"

    def resolve(image_id:)
      unless context[:current_api_key]
        raise GraphQL::ExecutionError.new("Invalid or missing API key", extensions: { "code" => "UNAUTHENTICATED" })
      end
      unless image_id.match?(IMAGE_ID_FORMAT)
        raise GraphQL::ExecutionError.new("Invalid image id", extensions: { "code" => "INVALID_INPUT" })
      end

      # Prefer the location Unsplash returned with the search (it carries the signed ixid);
      # client-supplied URLs are never fetched.
      location = Rails.cache.read(BackgroundImageSearch.download_location_cache_key(image_id)) ||
        "https://#{UnsplashClient::API_HOST}/photos/#{image_id}/download"
      TrackUnsplashDownloadJob.perform_later(location)

      { queued: true }
    end
  end
end
