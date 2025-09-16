# frozen_string_literal: true

module EE
  module DependencyProxy
    module CleanupDependencyProxyWorker
      extend ::Gitlab::Utils::Override

      override :perform
      def perform
        super
        enqueue_vreg_packages_cache_entry_cleanup_job
      end

      private

      def enqueue_vreg_packages_cache_entry_cleanup_job
        [::VirtualRegistries::Packages::Maven::Cache::Entry].each do |klass|
          if klass.pending_destruction.any?
            ::VirtualRegistries::Packages::Cache::DestroyOrphanEntriesWorker.perform_with_capacity(klass.name)
          end
        end
      end
    end
  end
end
