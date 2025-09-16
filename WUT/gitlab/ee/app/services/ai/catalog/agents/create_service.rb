# frozen_string_literal: true

module Ai
  module Catalog
    module Agents
      class CreateService < Ai::Catalog::BaseService
        SCHEMA_VERSION = 1

        def execute
          return error_no_permissions unless allowed?

          item_params = params.slice(:name, :description, :public)
          item_params.merge!(
            item_type: Ai::Catalog::Item::AGENT_TYPE,
            organization_id: project.organization_id,
            project_id: project.id
          )
          version_params = {
            schema_version: SCHEMA_VERSION,
            version: DEFAULT_VERSION,
            definition: {
              system_prompt: params[:system_prompt],
              user_prompt: params[:user_prompt]
            }
          }

          item = Ai::Catalog::Item.new(item_params)
          item.versions.build(version_params)

          return ServiceResponse.success(payload: item) if item.save

          error_creating(item)
        end

        private

        def error_creating(item)
          error(item.errors.full_messages.presence || 'Failed to create agent')
        end
      end
    end
  end
end
