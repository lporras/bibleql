# frozen_string_literal: true

module Types
  class BackgroundImageErrorCodeEnum < Types::BaseEnum
    description "Why a backgroundImages search returned no images"
    value "RATE_LIMITED", "The server's Unsplash quota is exhausted; try again later"
    value "UNAVAILABLE", "Unsplash could not be reached or returned an error"
    value "NOT_CONFIGURED", "Background image search is not configured on this server"
  end
end
