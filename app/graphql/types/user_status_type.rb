# frozen_string_literal: true

module Types
  # rubocop: disable Graphql/AuthorizeTypes
  class UserStatusType < BaseObject
    graphql_name 'UserStatus'

    markdown_field :message_html, null: true,
      description: 'HTML of the user status message'
    field :message, GraphQL::STRING_TYPE, null: true,
      description: 'User status message'
    field :emoji, GraphQL::STRING_TYPE, null: true,
      description: 'String representation of emoji'
    field :availability, Types::AvailabilityEnum, null: true,
      description: 'User availability status'
  end
end
