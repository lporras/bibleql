# The test environment uses :null_store, so nothing is ever cached. Tag an example group
# with `:with_cache` to run it against a fresh MemoryStore (also used by Rack::Attack and
# ApiKeyRateLimiter counters).
RSpec.configure do |config|
  config.around(:each, :with_cache) do |example|
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store = Rails.cache
    example.run
  ensure
    Rails.cache = original
    Rack::Attack.cache.store = original
  end
end
