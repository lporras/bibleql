# Server-side check of a Cloudflare Turnstile token (the widget on the API key request form).
# https://developers.cloudflare.com/turnstile/get-started/server-side-validation/
#
# On only when both TURNSTILE_SITE_KEY and TURNSTILE_SECRET_KEY are set, so development and test
# work without keys. Fails closed: a network error, an unreadable response, an unexpected action
# or a hostname outside the allowlist is a failed check.
#
# Hostname allowlist: TURNSTILE_HOSTNAMES (comma-separated), falling back to APP_HOST (the same
# value config.hosts uses). localhost/127.0.0.1 are never accepted in production. An empty
# allowlist rejects every token.
class TurnstileVerifier
  VERIFY_URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")
  TIMEOUT = 10
  MAX_TOKEN_LENGTH = 2048
  LOCAL_HOSTNAMES = %w[localhost 127.0.0.1].freeze

  # Widget action per protected form; the widget sends it and siteverify echoes it back.
  API_KEY_REQUEST_ACTION = "api_key_request".freeze

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

  def self.allowed_hostnames
    raw = ENV["TURNSTILE_HOSTNAMES"].presence || ENV["APP_HOST"].to_s
    hostnames = raw.split(",").map { |host| host.strip.downcase }.compact_blank.uniq
    hostnames -= LOCAL_HOSTNAMES if Rails.env.production?
    hostnames
  end

  def verify(token, action:, remote_ip: nil)
    return false unless token.is_a?(String) && token.present? && token.length <= MAX_TOKEN_LENGTH

    hostnames = self.class.allowed_hostnames
    if hostnames.empty?
      Rails.logger.error("[turnstile] no allowed hostnames: set TURNSTILE_HOSTNAMES or APP_HOST")
      return false
    end

    form = { secret: self.class.secret_key, response: token }
    form[:remoteip] = remote_ip if remote_ip.present?

    response = post(form)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("[turnstile] siteverify returned HTTP #{response.code}")
      return false
    end

    body = JSON.parse(response.body)
    failure = failure_reason(body, action:, hostnames:)
    if failure
      Rails.logger.info("[turnstile] verification failed: #{failure}")
      return false
    end

    Rails.logger.info("[turnstile] verified action=#{action} hostname=#{body['hostname']}")
    true
  rescue *NETWORK_ERRORS => e
    Rails.logger.warn("[turnstile] verification error: #{e.class}: #{e.message}")
    false
  end

  private

  def failure_reason(body, action:, hostnames:)
    return Array(body["error-codes"]).join(", ").presence || "not successful" unless body["success"] == true
    return "action mismatch (#{body['action'].inspect})" unless body["action"] == action
    "hostname not allowed (#{body['hostname'].inspect})" unless hostnames.include?(body["hostname"].to_s.downcase)
  end

  def post(form)
    request = Net::HTTP::Post.new(VERIFY_URL)
    request.set_form_data(form)
    Net::HTTP.start(VERIFY_URL.host, VERIFY_URL.port, use_ssl: true,
                    open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.request(request) }
  end
end
