# frozen_string_literal: true

module Gitlab
  module Geo
    class HealthCheck
      include Gitlab::Utils::StrongMemoize

      def perform_checks
        return '' unless Gitlab::Geo.secondary?
        return 'Geo database configuration file is missing.' unless Gitlab::Geo.geo_database_configured?
        return 'An existing tracking database cannot be reused.' if reusing_existing_tracking_database?
        return 'Geo node has a database that is writable which is an indication it is not configured for replication with the primary node.' unless ApplicationRecord.database.recovery?
        return 'Geo node does not appear to be replicating the database from the primary node.' if Feature.disabled?(:geo_postgresql_replication_agnostic, :instance) && replication_enabled? && !replication_working?
        return "Geo database version (#{database_version}) does not match latest migration (#{migration_version}).\nYou may have to run `gitlab-rake db:migrate:geo` as root on the secondary." unless database_migration_version_match?

        ''
      rescue StandardError => e
        e.message
      end

      def db_replication_lag_seconds
        # Geo currently only replicates the primary database (not the ci database)
        # Obtain the replication lag in seconds
        # If replication is disabled return nil
        return unless replication_enabled?

        ApplicationRecord.connection
          .execute(db_replication_lag_seconds_query)
          .first
          .fetch('replication_lag').to_i
      end

      def replication_enabled?
        streaming_replication_enabled? || archive_recovery_replication_enabled?
      end

      def replication_working?
        return streaming_replication_active? if streaming_replication_enabled?

        some_replication_active?
      end

      def reusing_existing_tracking_database?
        return false unless ::Geo::EventLogState.exists?
        return false if Gitlab::Geo.current_node.created_at.nil?

        Gitlab::Geo.current_node.created_at.utc > ::Geo::EventLogState.last.created_at.utc
      end

      private

      def db_replication_lag_seconds_query
        <<-SQL.squish
          SELECT CASE
            WHEN pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn()
              THEN 0
            ELSE
              EXTRACT (EPOCH FROM now() - pg_last_xact_replay_timestamp())::INTEGER
            END
            AS replication_lag
        SQL
      end

      def db_migrate_path
        # Lazy initialisation so Rails.root will be defined
        @db_migrate_path ||= File.join(Rails.root, 'ee', 'db', 'geo', 'migrate')
      end

      def db_post_migrate_path
        # Lazy initialisation so Rails.root will be defined
        @db_post_migrate_path ||= File.join(Rails.root, 'ee', 'db', 'geo', 'post_migrate')
      end

      def database_version
        strong_memoize(:database_version) do
          if defined?(ActiveRecord)
            connection = ::Geo::BaseRegistry.connection
            schema_migrations_table_name = ApplicationRecord.schema_migrations_table_name

            if connection.table_exists?(schema_migrations_table_name)
              connection.execute("SELECT MAX(version) AS version FROM #{schema_migrations_table_name}")
                        .first
                        .fetch('version')
            end
          end
        end
      end

      def migration_version
        strong_memoize(:migration_version) do
          latest_migration = nil

          Dir[File.join(db_migrate_path, "[0-9]*_*.rb"), File.join(db_post_migrate_path, "[0-9]*_*.rb")].each do |f|
            timestamp = begin
              f.scan(/0*([0-9]+)_[_.a-zA-Z0-9]*.rb/).first.first
            rescue StandardError
              -1
            end

            if latest_migration.nil? || timestamp.to_i > latest_migration.to_i
              latest_migration = timestamp
            end
          end

          latest_migration
        end
      end

      def database_migration_version_match?
        database_version.to_i == migration_version.to_i
      end

      def archive_recovery_replication_enabled?
        !streaming_replication_enabled? && some_replication_active?
      end

      def streaming_replication_enabled?
        !ApplicationRecord.connection
          .execute("SELECT * FROM pg_last_wal_receive_lsn() as result")
          .first['result']
          .nil?
      end

      def some_replication_active?
        # Is some sort of replication active?
        !ApplicationRecord.connection
          .execute("SELECT * FROM pg_last_xact_replay_timestamp() as result")
          .first['result']
          .nil?
      end

      def streaming_replication_active?
        # This only works for Postgresql 9.6 and greater
        ApplicationRecord.connection
          .select_values('SELECT pid FROM pg_stat_wal_receiver').first.to_i > 0
      end
    end
  end
end
