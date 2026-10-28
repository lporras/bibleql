# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    description "Mutations for client app installations. Bible data itself is read-only."

    field :register_installation, mutation: Mutations::RegisterInstallation,
      description: "Register a client app installation and get its API token (no API key required)"
    field :track_image_download, mutation: Mutations::TrackImageDownload, installation_only: true,
      description: "Report that a background image was used, as Unsplash's API guidelines require"

    # TODO: remove me
    field :test_field, String, null: false,
      description: "Scaffolding placeholder, not part of the supported API. Always returns \"Hello World\" and will be removed — do not depend on it."
    def test_field
      "Hello World"
    end
  end
end
