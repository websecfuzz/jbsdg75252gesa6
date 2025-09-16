# frozen_string_literal: true

module EE
  module MigrationsHelpers
    extend ::Gitlab::Utils::Override

    override :reset_column_information
    def reset_column_information(klass)
      super
    rescue ::Geo::TrackingBase::SecondaryNotConfigured
    end

    override :active_record_base
    def active_record_base(...)
      if custom_migration?
        db_base_model
      else
        super
      end
    end

    override :migrations_paths
    def migrations_paths
      if custom_migration?
        db_base_model.connection_db_config.configuration_hash[:migrations_paths]
      else
        super
      end
    end

    override :schema_migrate_down!
    def schema_migrate_down!
      with_db_config { super }
    end

    override :schema_migrate_up!
    def schema_migrate_up!
      with_db_config { super }
    end

    override :migrate!
    def migrate!
      with_db_config { super }
    end

    def with_db_config(&block)
      if custom_migration?
        with_custom_connection { yield }
      else
        yield
      end
    end

    def with_custom_connection
      with_reestablished_active_record_base(reconnect: true) do
        reconfigure_db_connection(
          name: geo_migration? ? :geo : :embedding,
          config_model: db_base_model,
          model: ActiveRecord::Base
        )

        yield
      end
    end

    def custom_migration?
      geo_migration? || embedding_migration?
    end

    def geo_migration?
      self.class.metadata[:geo]
    end

    def embedding_migration?
      self.class.metadata[:embedding]
    end

    def db_base_model
      if geo_migration?
        Geo::TrackingBase
      elsif embedding_migration?
        ::Embedding::ApplicationRecord
      else
        raise "unknown database migration"
      end
    end
  end
end
