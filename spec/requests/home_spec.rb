# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home", type: :request do
  # Captures the SQL a block issues, ignoring Rails' own schema lookups.
  def capture_sql
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:sql].start_with?("SET ")
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  describe "GET /" do
    it "renders successfully" do
      get root_path

      expect(response).to have_http_status(:ok)
    end

    # The regression guard for the production incident: counting 1.3M+ verses on
    # every request made this page take 9-46 seconds and saturated every Puma
    # thread, which in turn made /graphql time out. The landing page is static
    # marketing copy and must not touch the database at all.
    it "issues no database queries" do
      get root_path # warm any first-request bookkeeping
      queries = capture_sql { get root_path }

      expect(queries).to be_empty,
        "landing page queried the database:\n  #{queries.join("\n  ")}"
    end

    it "shows the static approximate corpus figures" do
      get root_path

      expect(response.body).to include(">40+<")   # translations
      expect(response.body).to include(">30+<")   # languages
      expect(response.body).to include(">1.3M+<") # verses
    end

    it "puts the same figures in the meta description" do
      get root_path

      expect(response.body).to match(/across 40\+ translations in 30\+ languages/)
    end

    it "links to the documentation site" do
      # A developer's local .env may point DOCS_URL at `bin/docs`, so pin it.
      stub_const("ENV", ENV.to_h.except("DOCS_URL"))

      get root_path

      expect(response.body).to include("https://docs.bibleql.org")
      expect(response.body).to include("Read the Docs")
    end
  end
end
