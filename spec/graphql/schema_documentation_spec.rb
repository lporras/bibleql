# frozen_string_literal: true

require "rails_helper"

# The published API reference at https://docs.bibleql.org is generated from the GraphQL
# schema, so an undescribed type, field or argument becomes a blank cell on a public
# documentation page. This spec keeps that from happening.
#
# If this fails, add a `description:` to whatever it names — do not weaken the spec.
RSpec.describe BibleqlSchema do
  # Introspection types (__Schema, __Type, ...) are graphql-ruby's own and are never published.
  def self.documentable_types(schema)
    schema.types.values.reject { |type| type.graphql_name.start_with?("__") }
  end

  describe "documentation coverage" do
    it "gives every type a description" do
      undescribed = self.class.documentable_types(described_class)
        .reject { |type| type.description.present? }
        .map(&:graphql_name)

      expect(undescribed).to be_empty,
        "These types have no description:\n  #{undescribed.join("\n  ")}"
    end

    it "gives every field a description" do
      undescribed = self.class.documentable_types(described_class).flat_map { |type|
        next [] unless type.respond_to?(:fields)

        type.fields.values
          .reject { |field| field.description.present? }
          .map { |field| "#{type.graphql_name}.#{field.graphql_name}" }
      }

      expect(undescribed).to be_empty,
        "These fields have no description:\n  #{undescribed.join("\n  ")}"
    end

    it "gives every argument a description" do
      undescribed = self.class.documentable_types(described_class).flat_map { |type|
        next [] unless type.respond_to?(:fields)

        type.fields.values.flat_map { |field|
          field.arguments.values
            .reject { |argument| argument.description.present? }
            .map { |argument| "#{type.graphql_name}.#{field.graphql_name}(#{argument.graphql_name}:)" }
        }
      }

      expect(undescribed).to be_empty,
        "These arguments have no description:\n  #{undescribed.join("\n  ")}"
    end

    it "gives every enum value a description" do
      undescribed = self.class.documentable_types(described_class)
        .select { |type| type.kind.enum? }
        .flat_map { |type|
          type.values.values
            .reject { |value| value.description.present? }
            .map { |value| "#{type.graphql_name}.#{value.graphql_name}" }
        }

      expect(undescribed).to be_empty,
        "These enum values have no description:\n  #{undescribed.join("\n  ")}"
    end
  end

  describe "the committed SDL" do
    let(:committed) { Rails.root.join("docs/generated/schema.graphql") }

    it "is checked in" do
      expect(committed).to exist,
        "Run `bundle exec rake docs:schema` and commit docs/generated/schema.graphql"
    end

    it "matches the current schema" do
      expect(committed.read).to eq(described_class.to_definition),
        "docs/generated/schema.graphql is stale. Run `bundle exec rake docs:schema` and commit the result."
    end
  end
end
