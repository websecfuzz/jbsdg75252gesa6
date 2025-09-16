# frozen_string_literal: true

module Mutations
  module AuditEvents
    module GoogleCloudLoggingConfigurations
      class Update < Base
        graphql_name 'GoogleCloudLoggingConfigurationUpdate'

        include Mutations::AuditEvents::GoogleCloudLoggingConfigurations::CommonUpdate

        UPDATE_EVENT_NAME = 'google_cloud_logging_configuration_updated'
        authorize :admin_external_audit_events

        argument :id, ::Types::GlobalIDType[::AuditEvents::GoogleCloudLoggingConfiguration],
          required: true,
          description: 'ID of the google Cloud configuration to update.'

        field :google_cloud_logging_configuration, ::Types::AuditEvents::GoogleCloudLoggingConfigurationType,
          null: true,
          description: 'configuration updated.'

        def resolve(
          id:, google_project_id_name: nil, client_email: nil, private_key: nil, log_id_name: nil, name: nil,
          active: nil)
          config, errors = update_config(id: id, google_project_id_name: google_project_id_name,
            client_email: client_email, private_key: private_key,
            log_id_name: log_id_name, name: name, active: active)

          { google_cloud_logging_configuration: config, errors: errors }
        end

        private

        def find_object(config_gid)
          GitlabSchema.object_from_id(
            config_gid,
            expected_type: ::AuditEvents::GoogleCloudLoggingConfiguration).sync
        end
      end
    end
  end
end
