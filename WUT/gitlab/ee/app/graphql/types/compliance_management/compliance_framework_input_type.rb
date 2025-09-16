# frozen_string_literal: true

module Types
  module ComplianceManagement
    class ComplianceFrameworkInputType < BaseInputObject
      graphql_name 'ComplianceFrameworkInput'

      argument :name,
        GraphQL::Types::String,
        required: false,
        description: 'New name for the compliance framework.'

      argument :description,
        GraphQL::Types::String,
        required: false,
        description: 'New description for the compliance framework.'

      argument :color,
        GraphQL::Types::String,
        required: false,
        description: 'New color representation of the compliance framework in hex format. e.g. #FCA121.'

      argument :default,
        GraphQL::Types::Boolean,
        required: false,
        description: 'Set the compliance framework as the default framework for the group.'

      argument :pipeline_configuration_full_path,
        GraphQL::Types::String,
        required: false,
        description: 'Full path of the compliance pipeline configuration stored in a project repository, such as `.gitlab/.compliance-gitlab-ci.yml@compliance/hipaa`. Ultimate only.',
        deprecated: { reason: 'Use pipeline execution policies instead', milestone: '17.4' }

      argument :projects,
        Types::ComplianceManagement::ProjectInputType,
        required: false,
        description: 'Projects to add or remove from the compliance framework.'
    end
  end
end
