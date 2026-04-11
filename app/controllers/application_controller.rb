class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_default_meta_tags

  private

  def set_default_meta_tags
    set_meta_tags(
      site: "BibleQL",
      separator: "|",
      reverse: true,
      description: "Free, open-source GraphQL Bible API. Query verses, passages, and full chapters across 43 translations in 31 languages.",
      canonical: request.original_url.split("?").first,
      og: {
        site_name: "BibleQL",
        type: "website",
        url: request.original_url,
        image: "#{request.base_url}/icon.png",
        locale: "en_US"
      },
      twitter: {
        card: "summary"
      }
    )
  end
end
