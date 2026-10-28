# frozen_string_literal: true

module Types
  class BackgroundImagePhotographerType < Types::BaseObject
    description "The Unsplash photographer to credit, as Unsplash's API guidelines require"

    field :name, String, null: false, description: "Photographer's display name"
    field :username, String, null: true, description: "Photographer's Unsplash handle"
    field :profile_url, String, null: true,
      description: "Photographer's Unsplash profile, with the required utm_source/utm_medium referral parameters"
  end
end
