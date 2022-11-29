# frozen_string_literal: true

module Types
  module WorkItems
    module Widgets
      # Disabling widget level authorization as it might be too granular
      # and we already authorize the parent work item
      # rubocop:disable Graphql/AuthorizeTypes
      class NotesType < BaseObject
        graphql_name 'WorkItemWidgetNotes'
        description 'Represents a notes widget'

        implements Types::WorkItems::WidgetInterface

        # This field loads user comments, system notes and resource events as a discussion for an work item,
        # raising the complexity considerably. In order to discourage fetching this field as part of fetching
        # a list of issues we raise the complexity
        field :discussions, Types::Notes::DiscussionType.connection_type,
          null: true,
          description: "Notes on this work item.",
          resolver: Resolvers::WorkItems::WorkItemDiscussionsResolver
      end
      # rubocop:enable Graphql/AuthorizeTypes
    end
  end
end
