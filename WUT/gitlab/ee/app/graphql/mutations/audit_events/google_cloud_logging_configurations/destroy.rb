# frozen_string_literal: true

module Mutations
  module AuditEvents
    module GoogleCloudLoggingConfigurations
      class Destroy < Base
        graphql_name 'GoogleCloudLoggingConfigurationDestroy'

        authorize :admin_external_audit_events

        argument :id, ::Types::GlobalIDType[::AuditEvents::GoogleCloudLoggingConfiguration],
          required: true,
          description: 'ID of the Google Cloud logging configuration to destroy.'

        def resolve(id:)
          config = authorized_find!(id)
          paired_destination = config.stream_destination

          if config.destroy
            audit(config, action: :deleted)

            if Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor, config.group)
              paired_destination&.destroy
            end

            { errors: [] }
          else
            { errors: Array(config.errors) }
          end
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
