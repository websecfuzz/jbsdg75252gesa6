# frozen_string_literal: true

module Sbom
  class DependencyLocationEntity < Grape::Entity
    include RequestAwareEntity

    class LocationEntity < Grape::Entity
      expose :blob_path, :path, :top_level
      expose :has_dependency_paths
    end

    class ProjectEntity < Grape::Entity
      expose :name
      expose :full_path
    end

    expose :location, using: LocationEntity
    expose :project, using: ProjectEntity
    expose :id, as: :occurrence_id
  end
end
