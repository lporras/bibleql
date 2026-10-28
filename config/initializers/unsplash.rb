# Unsplash API (official unsplash_rb gem), used only server-side by the backgroundImages proxy.
# The access key must never reach a client: ENV wins, Rails credentials (unsplash.access_key)
# are the fallback. No secret key is configured — only public Client-ID auth is used.
Unsplash.configure do |config|
  config.application_access_key = ENV["UNSPLASH_ACCESS_KEY"].presence ||
    Rails.application.credentials.dig(:unsplash, :access_key).presence
  # Referral id appended to every photo/photographer link; must match the app registered with Unsplash.
  config.utm_source = ENV["UNSPLASH_UTM_SOURCE"].presence || "bibleql-reader"
  config.logger = Rails.logger
end

# HTTParty has no default timeout; don't let a slow Unsplash hold a Puma thread.
Unsplash::Connection.default_timeout(5)
