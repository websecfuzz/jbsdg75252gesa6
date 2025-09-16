# frozen_string_literal: true

RSpec.shared_examples 'mark_one_batch_to_update_with_lease is using an exclusive lease guard' do
  include ExclusiveLeaseHelpers

  let(:lease_key) { "geo_bulk_update_service:#{registry_class.table_name}" }
  let(:lease_uuid) { 'uuid' }

  before do
    stub_exclusive_lease(lease_key, lease_uuid)
  end

  it 'does not enqueue the worker if the lease is taken' do
    stub_exclusive_lease_taken(lease_key)
    expect(service).not_to receive(:bulk_mark_update_one_batch!)

    service.mark_one_batch_to_update_with_lease!
  end

  it 'releases the lease when worker is enqueued' do
    allow(service).to receive(:bulk_mark_update_one_batch!)
    expect_to_cancel_exclusive_lease(lease_key, lease_uuid)

    service.mark_one_batch_to_update_with_lease!
  end

  it 'releases the lease when worker throws' do
    allow(service).to receive(:bulk_mark_update_one_batch!).and_raise(StandardError.new)
    expect_to_cancel_exclusive_lease(lease_key, lease_uuid)

    expect { service.mark_one_batch_to_update_with_lease! }.to raise_error(StandardError)
  end
end
