# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Cache::MarkEntriesForDestructionWorker, type: :worker, feature_category: :virtual_registry do
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream) }

  let(:worker) { described_class.new }

  subject(:perform) { worker.perform(upstream_id) }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky
  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [upstream.id] }
  end

  it 'has an until_executed deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  describe '#perform' do
    context 'when the upstream is found' do
      let(:upstream_id) { upstream.id }

      before do
        create_list(:virtual_registries_packages_maven_cache_entry, 3, upstream:) # 3 default
        create(:virtual_registries_packages_maven_cache_entry, :pending_destruction, upstream:) # 1 pending destruction
        create(:virtual_registries_packages_maven_cache_entry) # 1 default in another upstream
      end

      it 'marks default cache entries for destruction' do
        expect { perform }.to change {
          ::VirtualRegistries::Packages::Maven::Cache::Entry.pending_destruction.size
        }.by(3)
      end
    end

    context 'when the upstream is not found' do
      let(:upstream_id) { non_existing_record_id }

      it 'does not mark any cache entries for destruction' do
        expect { perform }.not_to change { ::VirtualRegistries::Packages::Maven::Cache::Entry.count }

        is_expected.to be_nil
      end
    end
  end
end
