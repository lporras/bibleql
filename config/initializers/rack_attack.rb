# frozen_string_literal: true

Rack::Attack.cache.store = Rails.cache

# Throttle all GraphQL requests by IP: 100 requests per minute
Rack::Attack.throttle("graphql/ip", limit: 100, period: 60.seconds) do |req|
  req.ip if req.path == "/graphql" && req.post?
end

# Throttle by API key: 1000 requests per day
Rack::Attack.throttle("graphql/api_key", limit: 1000, period: 1.day) do |req|
  if req.path == "/graphql" && req.post?
    auth_header = req.env["HTTP_AUTHORIZATION"]
    if auth_header&.start_with?("Bearer ")
      token = auth_header.delete_prefix("Bearer ")
      token[0, 12] # Use prefix as discriminator (avoids bcrypt at middleware level)
    end
  end
end

# Safelist health check
Rack::Attack.safelist("health_check") do |req|
  req.path == "/up" && req.get?
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
    [ { errors: [ { message: "Rate limit exceeded. Retry after #{retry_after} seconds." } ] }.to_json ]
  ]
end
