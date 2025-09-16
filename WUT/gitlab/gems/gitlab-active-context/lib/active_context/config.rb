# frozen_string_literal: true

module ActiveContext
  class Config
    Cfg = Struct.new(
      :enabled,
      :logger,
      :indexing_enabled,
      :re_enqueue_indexing_workers,
      :migrations_path,
      :connection_model,
      :collection_model
    )

    class << self
      def configure(&block)
        @instance = new(block)
      end

      def current
        @instance&.config || Cfg.new
      end

      def enabled?
        current.enabled || false
      end

      def migrations_path
        current.migrations_path || Rails.root.join('ee/db/active_context/migrate')
      end

      def connection_model
        current.connection_model || ::Ai::ActiveContext::Connection
      end

      def collection_model
        current.collection_model || ::Ai::ActiveContext::Collection
      end

      def logger
        current.logger || ::Logger.new($stdout)
      end

      def indexing_enabled?
        return false unless enabled?

        current.indexing_enabled || false
      end

      def re_enqueue_indexing_workers?
        current.re_enqueue_indexing_workers || false
      end
    end

    def initialize(config_block)
      @config_block = config_block
    end

    def config
      struct = Cfg.new
      @config_block.call(struct)
      struct
    end
  end
end
