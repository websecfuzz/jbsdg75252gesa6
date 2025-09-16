# frozen_string_literal: true

module Types
  class GroupReleaseStatsType < BaseObject
    graphql_name 'GroupReleaseStats'
    description 'Contains release-related statistics about a group'

    authorize :read_group_release_stats

    field :releases_count,
      GraphQL::Types::Int,
      null: true,
      description: 'Total number of releases in all descendant projects of the group.'

    field :releases_percentage,
      GraphQL::Types::Int,
      null: true,
      description: "Percentage of the group's descendant projects that have at least one release."
  end
end
