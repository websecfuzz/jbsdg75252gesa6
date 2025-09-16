# frozen_string_literal: true

module Types
  module Geo
    class GeoNodeType < BaseObject
      graphql_name 'GeoNode'

      authorize :read_geo_node

      field :ci_secure_file_registries, ::Types::Geo::CiSecureFileRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::CiSecureFileRegistriesResolver,
        description: 'Find Ci Secure File registries on this Geo node'
      field :container_repositories_max_capacity, GraphQL::Types::Int, null: true, description: 'Maximum concurrency of container repository sync for the secondary node.'
      field :container_repository_registries, ::Types::Geo::ContainerRepositoryRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::ContainerRepositoryRegistriesResolver,
        description: 'Find Container Repository registries on this Geo node.'
      field :dependency_proxy_blob_registries, ::Types::Geo::DependencyProxyBlobRegistryType.connection_type,
        null: true,
        experiment: { milestone: '15.6' },
        resolver: ::Resolvers::Geo::DependencyProxyBlobRegistriesResolver,
        description: 'Find Dependency Proxy Blob registries on this Geo node.'
      field :dependency_proxy_manifest_registries, ::Types::Geo::DependencyProxyManifestRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::DependencyProxyManifestRegistriesResolver,
        description: 'Find Dependency Proxy Manifest registries on this Geo node.'
      field :design_management_repository_registries, ::Types::Geo::DesignManagementRepositoryRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::DesignManagementRepositoryRegistriesResolver,
        description: 'Find Design Management Repository registries on this Geo node.',
        experiment: { milestone: '16.1' }
      field :enabled, GraphQL::Types::Boolean, null: true, description: 'Indicates whether the Geo node is enabled.'
      field :files_max_capacity, GraphQL::Types::Int, null: true, description: 'Maximum concurrency of LFS/attachment backfill for the secondary node.'
      field :group_wiki_repository_registries, ::Types::Geo::GroupWikiRepositoryRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::GroupWikiRepositoryRegistriesResolver,
        description: 'Find group wiki repository registries on this Geo node.'
      field :id, GraphQL::Types::ID, null: false, description: 'ID of the GeoNode.'
      field :internal_url, GraphQL::Types::String, null: true, description: 'URL defined on the primary node secondary nodes should use to contact it.'
      field :job_artifact_registries, ::Types::Geo::JobArtifactRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::JobArtifactRegistriesResolver,
        description: 'Find Job Artifact registries on this Geo node.'
      field :lfs_object_registries, ::Types::Geo::LfsObjectRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::LfsObjectRegistriesResolver,
        description: 'Find LFS object registries on this Geo node.'
      field :merge_request_diff_registries, ::Types::Geo::MergeRequestDiffRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::MergeRequestDiffRegistriesResolver,
        description: 'Find merge request diff registries on this Geo node.'
      field :minimum_reverification_interval, GraphQL::Types::Int, null: true, description: 'Interval (in days) in which the repository verification is valid. After expiry, it is reverted.'
      field :name, GraphQL::Types::String, null: true, description: 'Unique identifier for the Geo node.'
      field :package_file_registries, ::Types::Geo::PackageFileRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::PackageFileRegistriesResolver,
        description: 'Package file registries of the GeoNode.'
      field :pages_deployment_registries, ::Types::Geo::PagesDeploymentRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::PagesDeploymentRegistriesResolver,
        description: 'Find Pages Deployment registries on this Geo node'
      field :pipeline_artifact_registries, ::Types::Geo::PipelineArtifactRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::PipelineArtifactRegistriesResolver,
        description: 'Find pipeline artifact registries on this Geo node.'
      field :primary, GraphQL::Types::Boolean, null: true, description: 'Indicates whether the Geo node is the primary.'
      field :project_repository_registries, ::Types::Geo::ProjectRepositoryRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::ProjectRepositoryRegistriesResolver,
        description: 'Find Project registries on this Geo node. ' \
                     'Ignored if `geo_project_repository_replication` feature flag is disabled.'
      field :project_wiki_repository_registries, ::Types::Geo::ProjectWikiRepositoryRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::ProjectWikiRepositoryRegistriesResolver,
        description: 'Find Project Wiki Repository registries on this Geo node. ' \
                     'Ignored if `geo_project_wiki_repository_replication` feature flag is disabled.'
      field :repos_max_capacity, GraphQL::Types::Int, null: true, description: 'Maximum concurrency of repository backfill for the secondary node.'
      field :selective_sync_namespaces, ::Types::NamespaceType.connection_type, null: true, method: :namespaces, description: 'Namespaces that should be synced, if `selective_sync_type` == `namespaces`.'
      field :selective_sync_shards, type: [GraphQL::Types::String], null: true, description: 'Repository storages whose projects should be synced, if `selective_sync_type` == `shards`.'
      field :selective_sync_type, GraphQL::Types::String, null: true, description: 'Indicates if syncing is limited to only specific groups, or shards.'
      field :snippet_repository_registries, ::Types::Geo::SnippetRepositoryRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::SnippetRepositoryRegistriesResolver,
        description: 'Find snippet repository registries on this Geo node.'
      field :sync_object_storage, GraphQL::Types::Boolean, null: true, description: 'Indicates if the secondary node will replicate blobs in Object Storage.'
      field :terraform_state_version_registries, ::Types::Geo::TerraformStateVersionRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::TerraformStateVersionRegistriesResolver,
        description: 'Find terraform state version registries on this Geo node.'
      field :upload_registries, ::Types::Geo::UploadRegistryType.connection_type,
        null: true,
        resolver: ::Resolvers::Geo::UploadRegistriesResolver,
        description: 'Find Upload registries on this Geo node'
      field :url, GraphQL::Types::String, null: true, description: 'User-facing URL for the Geo node.'
      field :verification_max_capacity, GraphQL::Types::Int, null: true, description: 'Maximum concurrency of repository verification for the secondary node.'
    end
  end
end
