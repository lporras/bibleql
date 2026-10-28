# Backs the backgroundImages query: searches Unsplash through UnsplashClient, caches results,
# and maps photos into the shape BackgroundImageType exposes.
#
# Never raises for Unsplash failures. It returns an empty `images` list and an `error_code`
# (RATE_LIMITED / UNAVAILABLE / NOT_CONFIGURED) so clients can show an empty state instead of
# a GraphQL error.
class BackgroundImageSearch
  class InvalidQuery < StandardError; end

  DEFAULT_PER_PAGE = 24
  MAX_PER_PAGE = 30 # Unsplash's own maximum
  MAX_PAGE = 100
  MAX_QUERY_LENGTH = 100
  CACHE_TTL = 12.hours
  # Outlives CACHE_TTL so a cached search's photos can always still be tracked.
  DOWNLOAD_LOCATION_TTL = 24.hours
  BACKOFF_TTL = 5.minutes
  BACKOFF_KEY = "unsplash/backoff"
  URL_SIZES = %i[raw full regular small thumb].freeze

  ERROR_CODES = {
    UnsplashClient::RateLimited => "RATE_LIMITED",
    UnsplashClient::NotConfigured => "NOT_CONFIGURED",
    UnsplashClient::Unavailable => "UNAVAILABLE"
  }.freeze

  def self.download_location_cache_key(image_id)
    "unsplash/download_location/#{image_id}"
  end

  def initialize(query:, page: 1, per_page: DEFAULT_PER_PAGE, client: UnsplashClient.new)
    @query = query.to_s.strip.downcase.squeeze(" ").first(MAX_QUERY_LENGTH)
    raise InvalidQuery, "query must not be blank" if @query.blank?

    @page = page.to_i.clamp(1, MAX_PAGE)
    @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
    @client = client
  end

  def call
    cached = Rails.cache.read(cache_key)
    return cached if cached

    return failure("RATE_LIMITED") if Rails.cache.read(BACKOFF_KEY)

    result = fetch
    Rails.cache.write(cache_key, result, expires_in: CACHE_TTL)
    result
  rescue UnsplashClient::Error => e
    Rails.logger.warn("[unsplash] search failed: #{e.class.name.demodulize}: #{e.message}")
    Rails.cache.write(BACKOFF_KEY, true, expires_in: BACKOFF_TTL) if e.is_a?(UnsplashClient::RateLimited)
    failure(ERROR_CODES.fetch(e.class, "UNAVAILABLE"))
  end

  private

  def fetch
    photos = @client.search(query: @query, page: @page, per_page: @per_page)
    images = photos.map { |photo| map_photo(photo) }

    images.each do |image|
      next if image[:download_location].blank?

      Rails.cache.write(self.class.download_location_cache_key(image[:id]), image[:download_location],
        expires_in: DOWNLOAD_LOCATION_TTL)
    end

    { images: images, page: @page, total_pages: photos.total_pages.to_i, error_code: nil }
  end

  # The gem has already added Unsplash's required utm_source/utm_medium referral params to
  # the photo and photographer links.
  def map_photo(photo)
    {
      id: photo.id,
      width: photo.width,
      height: photo.height,
      color: photo.color,
      blur_hash: photo.blur_hash,
      alt_description: photo.alt_description,
      urls: photo.urls.to_h.symbolize_keys.slice(*URL_SIZES),
      photographer: {
        name: photo.user.name,
        username: photo.user.username,
        profile_url: photo.user.links.html
      },
      unsplash_url: photo.links.html,
      download_location: photo.links.download_location
    }
  end

  def failure(code)
    { images: [], page: @page, total_pages: 0, error_code: code }
  end

  def cache_key
    "unsplash/search/v1/#{Digest::SHA256.hexdigest(@query)}/#{@page}/#{@per_page}"
  end
end
