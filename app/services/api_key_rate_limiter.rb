# Per-key daily request quota, enforced in GraphqlController after authentication.
#
# Lives here rather than in Rack::Attack because the limit depends on the key's kind and
# deprecated flag, which middleware can't see without a database lookup (and token prefixes
# are too short to tell installation keys apart).
class ApiKeyRateLimiter
  Result = Data.define(:allowed, :count, :limit, :retry_after) do
    alias_method :allowed?, :allowed
  end

  def self.check!(api_key, now: Time.current)
    new(api_key, now).check!
  end

  def initialize(api_key, now)
    @api_key = api_key
    @now = now
  end

  # Counts this request and reports whether it fits in today's quota (UTC day).
  def check!
    count = Rails.cache.increment(cache_key, 1, expires_in: 25.hours).to_i
    limit = @api_key.daily_limit

    Result.new(allowed: count <= limit, count: count, limit: limit, retry_after: seconds_until_reset)
  end

  private

  def cache_key
    "api_key_quota/#{@api_key.id}/#{@now.utc.to_date.iso8601}"
  end

  def seconds_until_reset
    (@now.utc.end_of_day - @now.utc).ceil
  end
end
