# Server-side check of a Cloudflare Turnstile token (the widget on the API key request form).
# https://developers.cloudflare.com/turnstile/get-started/server-side-validation/
#
# On only when both TURNSTILE_SITE_KEY and TURNSTILE_SECRET_KEY are set, so development and test
# work without keys. Fails closed: a network error or an unreadable response is a failed check.
class TurnstileVerifier
  VERIFY_URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")
  TIMEOUT = 5

  NETWORK_ERRORS = [
    SocketError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError, EOFError,
    Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH
  ].freeze

  def self.site_key
    ENV["TURNSTILE_SITE_KEY"].presence
  end

  def self.secret_key
    ENV["TURNSTILE_SECRET_KEY"].presence
  end

  def self.enabled?
    site_key.present? && secret_key.present?
  end

  def verify(token, remote_ip: nil)
    return false if token.blank?

    form = { secret: self.class.secret_key, response: token }
    form[:remoteip] = remote_ip if remote_ip.present?

    body = JSON.parse(post(form).body)
    return true if body["success"] == true

    Rails.logger.info("[turnstile] verification failed: #{Array(body['error-codes']).join(', ')}")
    false
  rescue *NETWORK_ERRORS => e
    Rails.logger.warn("[turnstile] verification error: #{e.class}: #{e.message}")
    false
  end

  private

  def post(form)
    request = Net::HTTP::Post.new(VERIFY_URL)
    request.set_form_data(form)
    Net::HTTP.start(VERIFY_URL.host, VERIFY_URL.port, use_ssl: true,
                    open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(request) }
  end
end
