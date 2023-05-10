# frozen_string_literal: true

module Types
  module Ai
    # rubocop:disable Graphql/AuthorizeTypes
    # Authorizations can happen at the field level
    # read_project is checked on the project type
    class ProjectConversationsType < Types::BaseObject
      field :ci_config_messages,
        Types::Ai::MessageType.connection_type,
        null: true,
        description: "Messages generated by open ai and the user.",
        alpha: { milestone: '16.0' }
    end
    # rubocop:enable Graphql/AuthorizeTypes
  end
end
