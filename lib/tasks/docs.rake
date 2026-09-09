# frozen_string_literal: true

namespace :docs do
  desc "Export the GraphQL schema SDL to docs/generated/schema.graphql"
  task schema: :environment do
    # Static schema printing — no database connection, submodules or credentials required,
    # which is what lets the docs workflow run on Node alone.
    path = Rails.root.join("docs/generated/schema.graphql")
    path.dirname.mkpath
    path.write(BibleqlSchema.to_definition)

    puts "Wrote #{path.relative_path_from(Rails.root)} (#{path.size} bytes)"
  end
end
