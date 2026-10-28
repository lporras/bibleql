# frozen_string_literal: true

module Types
  class BaseField < GraphQL::Schema::Field
    argument_class Types::BaseArgument

    # `installation_only: true` hides a field from everyone except installation keys (the
    # BibleQL client apps): it is absent from introspection, from the exported SDL (and so
    # from the public API reference), and querying it with any other key fails validation.
    def initialize(*args, installation_only: false, **kwargs, &block)
      @installation_only = installation_only
      super(*args, **kwargs, &block)
    end

    def visible?(context)
      return super unless @installation_only

      super && context[:current_api_key]&.installation? == true
    end
  end
end
