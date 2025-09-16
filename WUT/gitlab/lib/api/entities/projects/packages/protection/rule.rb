# frozen_string_literal: true

module API
  module Entities
    module Projects
      module Packages
        module Protection
          class Rule < Grape::Entity
            expose :id, documentation: { type: 'integer', example: 1 }
            expose :project_id, documentation: { type: 'integer', example: 1 }
            expose :package_name_pattern, documentation: { type: 'string', example: 'flightjs/flight' }
            expose :package_type, documentation: { type: 'string', example: 'npm' }
            expose :minimum_access_level_for_delete, documentation: { type: 'string', example: 'owner' }
            expose :minimum_access_level_for_push, documentation: { type: 'string', example: 'maintainer' }

            def minimum_access_level_for_delete
              return if ::Feature.disabled?(:packages_protected_packages_delete, object.project)

              object.minimum_access_level_for_delete
            end
          end
        end
      end
    end
  end
end
