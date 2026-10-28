require "webmock/rspec"

# Specs never reach real external APIs (Unsplash). Localhost stays open for system specs.
WebMock.disable_net_connect!(allow_localhost: true)
