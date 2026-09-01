# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Playground", type: :request do
  # The playground ships every example as a named operation so they can all stay
  # uncommented and be picked from GraphiQL's execute dropdown. An unnamed or
  # duplicated operation breaks that with "Operation name is required when
  # multiple operations are present".
  let(:document) do
    source = Rails.root.join("app/views/playground/show.html.erb").read
    source[/const defaultQuery = `(.*?)`;/m, 1] or raise "could not extract defaultQuery"
  end

  let(:operations) do
    GraphQL.parse(document).definitions.grep(GraphQL::Language::Nodes::OperationDefinition)
  end

  it "renders" do
    get "/playground"
    expect(response).to have_http_status(:ok)
  end

  describe "the default query" do
    it "parses as a valid GraphQL document" do
      expect { GraphQL.parse(document) }.not_to raise_error
    end

    it "names every operation" do
      expect(operations.map(&:name)).to all(be_present)
    end

    it "gives every operation a unique name" do
      duplicates = operations.map(&:name).tally.select { |_name, count| count > 1 }
      expect(duplicates).to be_empty
    end

    it "validates every operation against the schema" do
      failures = operations.filter_map do |operation|
        query = GraphQL::Query.new(BibleqlSchema, document, operation_name: operation.name)
        errors = BibleqlSchema.validate(query.document)
        "#{operation.name}: #{errors.map(&:message).join(', ')}" if errors.any?
      end

      expect(failures).to be_empty
    end
  end
end
