# Wraps the official Unsplash gem (unsplash_rb, configured in config/initializers/unsplash.rb)
# for the backgroundImages query and trackImageDownload mutation, so client apps never hold
# the access key.
#
# Every failure is re-raised as an UnsplashClient::Error subclass, so callers deal with one
# hierarchy instead of the gem's errors plus raw HTTP/network exceptions. Messages come from
# Unsplash's response bodies and never include the access key or request headers.
class UnsplashClient
  API_HOST = "api.unsplash.com"
  DOWNLOAD_PATH = %r{\A/photos/[\w-]+/download\z}

  class Error < StandardError; end
  class NotConfigured < Error; end
  class RateLimited < Error; end
  class Unavailable < Error; end

  NETWORK_ERRORS = [
    HTTParty::Error, SocketError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError,
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH
  ].freeze

  def self.configured?
    Unsplash.configuration.application_access_key.present?
  end

  # Returns an Unsplash::SearchResult: an Array of Unsplash::Photo with #total_pages.
  def search(query:, page:, per_page:)
    call_unsplash { Unsplash::Photo.search(query, page, per_page, nil, "high") }
  end

  # Unsplash's required "photo was used" ping, sent to a photo's links.download_location.
  # The access key is attached, so only https://api.unsplash.com/photos/:id/download is allowed.
  def track_download(download_location)
    uri = URI.parse(download_location.to_s)
    unless uri.is_a?(URI::HTTPS) && uri.host == API_HOST && uri.path.match?(DOWNLOAD_PATH)
      raise Unavailable, "Refusing to send the access key to a non-Unsplash download URL"
    end

    call_unsplash { Unsplash::Photo.new("links" => { "download_location" => uri.to_s }).track_download }
  rescue URI::InvalidURIError
    raise Unavailable, "Invalid download URL"
  end

  private

  def call_unsplash
    raise NotConfigured, "Unsplash access key is not configured" unless self.class.configured?

    yield
  rescue Unsplash::UnauthorizedError
    raise NotConfigured, "Unsplash rejected the access key"
  rescue Unsplash::Error => e
    # Unsplash's rate-limit 403 has a plain-text "Rate Limit Exceeded" body, which the gem
    # surfaces as a generic Unsplash::Error carrying that body as its message.
    raise RateLimited, "Unsplash rate limit exceeded" if e.message.include?("Rate Limit Exceeded")

    raise Unavailable, "Unsplash request failed: #{e.message.truncate(200)}"
  rescue *NETWORK_ERRORS => e
    raise Unavailable, "Unsplash request failed (#{e.class.name})"
  end
end
