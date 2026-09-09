# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    description "BibleQL is a read-only API. No mutations are supported; this root exists only as scaffolding."

    # TODO: remove me
    field :test_field, String, null: false,
      description: "Scaffolding placeholder, not part of the supported API. Always returns \"Hello World\" and will be removed — do not depend on it."
    def test_field
      "Hello World"
    end
  end
end
