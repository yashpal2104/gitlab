# frozen_string_literal: true

module Types
  module Ci
    # rubocop: disable Graphql/AuthorizeTypes
    class CodeQualityDegradationType < BaseObject
      graphql_name 'CodeQualityDegradation'
      description 'Represents a code quality degradation on the pipeline.'

      connection_type_class(Types::CountableConnectionType)

      alias_method :degradation, :object

      field :description, GraphQL::STRING_TYPE, null: false,
        description: "A description of the code quality degradation."

      field :fingerprint, GraphQL::STRING_TYPE, null: false,
        description: 'A unique fingerprint to identify the code quality degradation. For example, an MD5 hash.'

      field :severity, Types::Ci::CodeQualityDegradationSeverityEnum, null: false,
        description: "Status of the degradation (#{::Gitlab::Ci::Reports::CodequalityReports::SEVERITY_PRIORITIES.keys.map(&:upcase).join(', ')})."

      field :path, GraphQL::STRING_TYPE, null: false,
        description: 'The relative path to the file containing the code quality degradation.'

      def path
        degradation.dig(:location, :path)
      end

      field :line, GraphQL::INT_TYPE, null: false,
        description: 'The line on which the code quality degradation occurred.'

      def line
        degradation.dig(:location, :lines, :begin) || degradation.dig(:location, :positions, :begin, :line)
      end
    end
  end
end
