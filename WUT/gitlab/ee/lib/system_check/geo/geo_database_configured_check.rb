# frozen_string_literal: true

module SystemCheck
  module Geo
    class GeoDatabaseConfiguredCheck < SystemCheck::BaseCheck
      set_name 'GitLab Geo tracking database is correctly configured'
      set_skip_reason 'not a secondary node'

      WRONG_CONFIGURATION_MESSAGE = <<~MSG
        Rails does not appear to have the configuration necessary to connect to the Geo tracking database.
        If the tracking database is running on a node other than this one, then you may need to add configuration.
      MSG
      UNHEALTHY_CONNECTION_MESSAGE = 'Check the tracking database configuration as the connection could not be established'
      NO_TABLES_MESSAGE = 'Run the tracking database migrations: gitlab-rake db:migrate:geo'
      REUSING_EXISTING_DATABASE_MESSAGE = 'If you are reusing an existing tracking database, make sure you have reset it.'

      def skip?
        !Gitlab::Geo.secondary?
      end

      def multi_check
        return error_message(WRONG_CONFIGURATION_MESSAGE) unless Gitlab::Geo.geo_database_configured?
        return error_message(UNHEALTHY_CONNECTION_MESSAGE) unless ::Geo::TrackingBase.connected?
        return error_message(NO_TABLES_MESSAGE) unless tables_present?
        return error_message(REUSING_EXISTING_DATABASE_MESSAGE, troubleshooting_docs) unless fresh_database?

        $stdout.puts Rainbow('yes').green
        true
      end

      def database_docs
        Rails.application.routes.url_helpers.help_page_url('administration/geo/setup/database.md')
      end

      def troubleshooting_docs
        Rails.application.routes.url_helpers.help_page_url('administration/geo/replication/troubleshooting/_index.md')
      end

      private

      def tables_present?
        !needs_migration?
      end

      def needs_migration?
        !(migrations.collect(&:version) - get_all_versions).empty?
      end

      def get_all_versions
        if schema_migration.table_exists?
          schema_migration.all_versions.map(&:to_i)
        else
          []
        end
      end

      def migrations
        ::Geo::TrackingBase.connection.migration_context.migrations
      end

      def schema_migration
        ::Geo::TrackingBase::SchemaMigration
      end

      def geo_health_check
        @geo_health_check ||= Gitlab::Geo::HealthCheck.new
      end

      def fresh_database?
        !geo_health_check.reusing_existing_tracking_database?
      end

      def error_message(message, docs = database_docs)
        $stdout.puts Rainbow('no').red
        try_fixing_it(message)
        for_more_information(docs)

        false
      end
    end
  end
end
