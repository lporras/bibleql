# frozen_string_literal: true

Rack::Attack.cache.store = Rails.cache

# Throttle all GraphQL requests by IP: 100 requests per minute
Rack::Attack.throttle("graphql/ip", limit: 100, period: 60.seconds) do |req|
  req.ip if req.path == "/graphql" && req.post?
end

# Throttle GraphQL requests without an Authorization header: 10 per hour per IP. The only
# thing such a request can do is registerInstallation (see GraphqlController#registration_request?),
# so this is the registration limit — the main way around per-key limits is minting new keys.
Rack::Attack.throttle("graphql/unauthenticated/ip", limit: 10, period: 1.hour) do |req|
  req.ip if req.path == "/graphql" && req.post? && req.env["HTTP_AUTHORIZATION"].blank?
end

# Per-API-key daily limits are enforced in GraphqlController (ApiKeyRateLimiter), since they
# depend on the key's kind and deprecated flag.

# Throttle API key request form: 5 submissions per hour per IP
Rack::Attack.throttle("api_key_requests/ip", limit: 5, period: 1.hour) do |req|
  req.ip if req.path.start_with?("/api-keys/request") && req.post?
end

# Safelist health check. Uptime monitors and Render's own probe use HEAD as often
# as GET, and req.get? is false for HEAD.
Rack::Attack.safelist("health_check") do |req|
  req.path == "/up" && (req.get? || req.head?)
end

# Custom 429 response with JSON body
Rack::Attack.throttled_responder = lambda do |req|
  match_data = req.env["rack.attack.match_data"]
  retry_after = match_data[:period] - (Time.now.to_i % match_data[:period])

  [
    429,
    {
      "Content-Type" => "application/json",
      "Retry-After" => retry_after.to_s
    },
    [ { errors: [ { message: "Rate limit exceeded. Retry after #{retry_after} seconds.", extensions: { code: "RATE_LIMITED", retryAfter: retry_after } } ] }.to_json ]
  ]
end
