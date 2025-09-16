# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module FixIncompleteExternalAuditDestinations
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class ExternalAuditEventDestination < ::ApplicationRecord
          self.table_name = 'audit_events_external_audit_event_destinations'

          belongs_to :group, class_name: '::Group', foreign_key: 'namespace_id'
          belongs_to :stream_destination, class_name: 'GroupStreamingDestination', optional: true
        end

        class LegacyHeader < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_headers'
        end

        class LegacyEventTypeFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_event_type_filters'
        end

        class LegacyGroupNamespaceFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_http_group_namespace_filters'
        end

        class GroupStreamingDestination < ::ApplicationRecord
          include ::Gitlab::EncryptedAttribute

          self.table_name = 'audit_events_group_external_streaming_destinations'
          enum :category, { http: 0, gcp: 1, aws: 2 }

          attr_accessor :secret_token

          attr_encrypted :secret_token,
            mode: :per_attribute_iv,
            key: :db_key_base_32,
            algorithm: 'aes-256-gcm',
            encode: false,
            encode_iv: false
        end

        class GroupEventTypeFilter < ::ApplicationRecord
          self.table_name = 'audit_events_group_streaming_event_type_filters'
        end

        class GroupNamespaceFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_group_namespace_filters'
        end

        prepended do
          operation_name :fix_external_audit_destinations_migration
          feature_category :audit_events
          scope_to ->(relation) { relation }
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            process_batch(sub_batch)
          end
        end

        private

        def process_batch(sub_batch)
          sub_batch.each do |legacy_destination|
            ::ApplicationRecord.transaction do
              if legacy_destination.stream_destination_id.present?
                sync_migrated_record(legacy_destination)
              else
                migrate_new_record(legacy_destination)
              end
            end
          end
        end

        def sync_migrated_record(legacy_destination)
          destination = GroupStreamingDestination.find_by(id: legacy_destination.stream_destination_id)
          return unless destination

          sync_custom_headers(legacy_destination, destination)
          sync_event_type_filters(legacy_destination, destination)
          sync_namespace_filter(legacy_destination, destination)
        end

        def migrate_new_record(legacy_destination)
          return unless legacy_destination.verification_token.present?

          destination = GroupStreamingDestination.new(
            name: legacy_destination.name,
            category: :http,
            config: build_config(legacy_destination),
            legacy_destination_ref: legacy_destination.id,
            group_id: legacy_destination.namespace_id,
            created_at: legacy_destination.created_at,
            updated_at: legacy_destination.updated_at
          )

          destination.secret_token = legacy_destination.verification_token
          return unless destination.save

          legacy_destination.update_column(:stream_destination_id, destination.id)

          migrate_event_type_filters(legacy_destination, destination)
          migrate_namespace_filter(legacy_destination, destination)

          destination
        end

        def build_config(legacy_destination)
          headers = LegacyHeader.where(external_audit_event_destination_id: legacy_destination.id)
                               .pluck(:key, :value, :active)

          header_config = {
            'X-Gitlab-Event-Streaming-Token' => {
              'value' => legacy_destination.verification_token,
              'active' => true
            }
          }

          headers.each do |key, value, active|
            header_config[key] = {
              'value' => value,
              'active' => active
            }
          end

          {
            'url' => legacy_destination.destination_url,
            'headers' => header_config
          }
        end

        def sync_custom_headers(legacy_destination, destination)
          headers = LegacyHeader.where(external_audit_event_destination_id: legacy_destination.id)
                              .pluck(:key, :value, :active)

          return if headers.empty?

          config = destination.config.deep_dup
          config['headers'] ||= {}

          if legacy_destination.verification_token.present? &&
              !config['headers'].key?('X-Gitlab-Event-Streaming-Token')
            config['headers']['X-Gitlab-Event-Streaming-Token'] = {
              'value' => legacy_destination.verification_token,
              'active' => true
            }
          end

          headers.each do |key, value, active|
            next if config['headers'].key?(key)

            config['headers'][key] = {
              'value' => value,
              'active' => active
            }
          end

          destination.update!(config: config)
        end

        def sync_event_type_filters(legacy_destination, destination)
          existing_filters = GroupEventTypeFilter
                              .where(external_streaming_destination_id: destination.id)
                              .pluck(:audit_event_type)

          legacy_filters = LegacyEventTypeFilter
                            .where(external_audit_event_destination_id: legacy_destination.id)
                            .pluck(:audit_event_type, :created_at, :updated_at)

          missing_filters = legacy_filters.reject { |filter| existing_filters.include?(filter[0]) }

          return if missing_filters.empty?

          attributes = missing_filters.map do |audit_event_type, created_at, updated_at|
            {
              audit_event_type: audit_event_type,
              created_at: created_at,
              updated_at: updated_at,
              external_streaming_destination_id: destination.id,
              namespace_id: legacy_destination.namespace_id
            }
          end

          GroupEventTypeFilter.insert_all!(attributes)
        end

        def migrate_event_type_filters(legacy_destination, destination)
          filters = LegacyEventTypeFilter.where(
            external_audit_event_destination_id: legacy_destination.id
          ).pluck(:audit_event_type, :created_at, :updated_at)

          return if filters.empty?

          attributes = filters.map do |audit_event_type, created_at, updated_at|
            {
              audit_event_type: audit_event_type,
              created_at: created_at,
              updated_at: updated_at,
              external_streaming_destination_id: destination.id,
              namespace_id: legacy_destination.namespace_id
            }
          end

          GroupEventTypeFilter.insert_all!(attributes)
        end

        def sync_namespace_filter(legacy_destination, destination)
          existing_filter = GroupNamespaceFilter.find_by(external_streaming_destination_id: destination.id)
          return if existing_filter

          legacy_filter = LegacyGroupNamespaceFilter.find_by(
            external_audit_event_destination_id: legacy_destination.id
          )

          return unless legacy_filter

          GroupNamespaceFilter.create!(
            namespace_id: legacy_filter.namespace_id,
            external_streaming_destination_id: destination.id,
            created_at: legacy_filter.created_at,
            updated_at: legacy_filter.updated_at
          )
        end

        def migrate_namespace_filter(legacy_destination, destination)
          filter = LegacyGroupNamespaceFilter.find_by(
            external_audit_event_destination_id: legacy_destination.id
          )

          return unless filter

          GroupNamespaceFilter.create!(
            namespace_id: filter.namespace_id,
            external_streaming_destination_id: destination.id,
            created_at: filter.created_at,
            updated_at: filter.updated_at
          )
        end
      end
    end
  end
end
