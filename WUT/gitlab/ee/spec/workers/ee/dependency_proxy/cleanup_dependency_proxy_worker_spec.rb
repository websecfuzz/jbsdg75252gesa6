# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyProxy::CleanupDependencyProxyWorker, type: :worker, feature_category: :virtual_registry do
  describe '#perform' do
    subject(:worker_perform) { described_class.new.perform }

    context 'when there are records to be deleted' do
      it_behaves_like 'an idempotent worker' do
        it 'queues the cleanup jobs', :aggregate_failures do
          create(:virtual_registries_packages_maven_cache_entry, :pending_destruction)

          expect(::VirtualRegistries::Packages::Cache::DestroyOrphanEntriesWorker)
            .to receive(:perform_with_capacity).once

          worker_perform
        end
      end
    end

    context 'when there are no records to be deleted' do
      it_behaves_like 'an idempotent worker' do
        it 'does not queue the cleanup jobs', :aggregate_failures do
          expect(::VirtualRegistries::Packages::Cache::DestroyOrphanEntriesWorker)
            .not_to receive(:perform_with_capacity)

          worker_perform
        end
      end
    end
  end
end
