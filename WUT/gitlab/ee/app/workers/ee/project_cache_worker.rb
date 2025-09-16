# frozen_string_literal: true

module EE
  # Geo specific code for cache re-generation
  #
  # This module is intended to encapsulate EE-specific methods
  # and be **prepended** in the `ProjectCacheWorker` class.
  module ProjectCacheWorker
    def perform(...)
      if ::Gitlab::Geo.secondary?
        perform_geo_secondary(...)
      else
        super
      end
    end

    private

    # Geo should only update Redis based cache, as data store in the database
    # will be updated on primary and replicated to the secondaries.
    def perform_geo_secondary(project_id, refresh = [], _statistics = [])
      project = ::Project.find_by_id(project_id)

      return unless project && project.repository.exists?

      project.repository.refresh_method_caches(refresh.map(&:to_sym))
    end
  end
end
