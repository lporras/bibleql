# Decides whether an API key request looks like a bot before any key is made or email sent.
# Each rule matches something seen in real spam runs on the form (see BotApiKeyCleanup) and
# that a person asking for a key wouldn't do. Overlong names are a model validation instead
# (ApiKeyRequest::NAME_MAX_LENGTH), so they get a visible form error.
#
# The controller rejects flagged requests silently: the bot sees the normal success page, so it
# can't tell which rule caught it, and an admin can still approve a false positive
# ("Resend Approval" on the rejected request).
class ApiKeyRequestSpamCheck
  LINK_PATTERN = %r{https?://|www\.|\b[\w-]+\.(?:com|net|org|info|biz|ru|xyz|top|site|online|io|php)\b}i
  SEO_DESCRIPTION_PREFIX = "I would like more information. Please contact me by email"
  BLOCKED_EMAIL_DOMAINS = %w[1win.com 1win.xyz].freeze

  # honeypot: the hidden form field real browsers leave empty.
  def initialize(api_key_request, honeypot: nil)
    @request = api_key_request
    @honeypot = honeypot
  end

  def spam?
    reasons.any?
  end

  def reasons
    @reasons ||= [].tap do |reasons|
      name = @request.name.to_s
      reasons << "honeypot filled" if @honeypot.present?
      reasons << "link in name" if name.match?(LINK_PATTERN)
      reasons << "known spam description" if @request.description.to_s.strip.start_with?(SEO_DESCRIPTION_PREFIX)
      reasons << "blocked email domain" if BLOCKED_EMAIL_DOMAINS.include?(email_domain)
    end
  end

  private

  def email_domain
    @request.email.to_s.strip.downcase.split("@", 2).last
  end
end
