module UnsplashHelpers
  UNSPLASH_TEST_ACCESS_KEY = "unsplash-test-access-key-SECRET"
  UNSPLASH_SEARCH_URL = %r{\Ahttps://api\.unsplash\.com/search/photos}

  def unsplash_search_body
    file_fixture("unsplash_search.json").read
  end

  def stub_unsplash_search(body: unsplash_search_body, status: 200, headers: { "Content-Type" => "application/json" })
    stub_request(:get, UNSPLASH_SEARCH_URL).to_return(status: status, body: body, headers: headers)
  end
end

RSpec.configure do |config|
  config.include UnsplashHelpers

  # Never use a developer's real key from .env (dotenv-rails loads it in test too).
  # The gem memoizes its connection, which captures the key, so rebuild it each example.
  config.before do
    Unsplash.configuration.application_access_key = UnsplashHelpers::UNSPLASH_TEST_ACCESS_KEY
    Unsplash::Client.connection = Unsplash::Connection.new
  end
end
