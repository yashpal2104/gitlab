# frozen_string_literal: true

module Resolvers
  class BlobsResolver < BaseResolver
    include Gitlab::Graphql::Authorize::AuthorizeResource

    type Types::Tree::BlobType.connection_type, null: true
    authorize :read_code
    calls_gitaly!

    alias_method :repository, :object

    argument :paths, [GraphQL::Types::String],
             required: true,
             description: 'Array of desired blob paths.'
    argument :ref, GraphQL::Types::String,
             required: false,
             default_value: nil,
             description: 'Commit ref to get the blobs from. Default value is HEAD.'

    # We fetch blobs from Gitaly efficiently but it still scales O(N) with the
    # number of paths being fetched, so apply a scaling limit to that.
    def self.resolver_complexity(args, child_complexity:, context:)
      super + (args[:paths] || []).size
    end

    def resolve(paths:, ref:)
      authorize!(repository.container)

      return [] if repository.empty?

      ref ||= repository.root_ref
      validate_ref(ref)

      repository.blobs_at(paths.map { |path| [ref, path] })
    end

    private

    def validate_ref(ref)
      unless Gitlab::GitRefValidator.validate(ref)
        raise Gitlab::Graphql::Errors::ArgumentError, 'Ref is not valid'
      end
    end
  end
end
