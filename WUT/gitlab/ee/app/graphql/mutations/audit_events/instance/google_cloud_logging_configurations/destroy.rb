# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Instance
      module GoogleCloudLoggingConfigurations
        class Destroy < Base
          graphql_name 'InstanceGoogleCloudLoggingConfigurationDestroy'

          argument :id, ::Types::GlobalIDType[::AuditEvents::Instance::GoogleCloudLoggingConfiguration],
            required: true,
            description: 'ID of the Google Cloud logging configuration to destroy.'

          def resolve(id:)
            config = authorized_find!(id)
            paired_destination = config.stream_destination

            if config.destroy
              audit(config, action: :deleted)

              if Feature.enabled?(:audit_events_external_destination_streamer_consolidation_refactor,
                :instance)
                paired_destination&.destroy
              end
            end

            { errors: Array(config.errors) }
          end
        end
      end
    end
  end
end
