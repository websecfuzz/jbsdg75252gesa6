# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GeoNodeStatus, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  using RSpec::Parameterized::TableSyntax

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary) { create(:geo_node, :secondary) }

  let_it_be(:group)     { create(:group) }
  let_it_be(:project_1) { create(:project, group: group) }
  let_it_be(:project_2) { create(:project, group: group) }
  let_it_be(:project_3) { create(:project) }
  let_it_be(:project_4) { create(:project) }

  subject(:status) { described_class.current_node_status }

  before do
    # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
    # is not allowed within a transaction but all RSpec tests run inside of a transaction.
    stub_batch_counter_transaction_open_check
    stub_current_geo_node(secondary)

    primary.reload_status
    secondary.reload_status
  end

  describe '#fast_current_node_status' do
    it 'reads the cache and spawns the worker' do
      expect(described_class).to receive(:spawn_worker).once

      rails_cache = double
      expect(rails_cache).to receive(:read).with(described_class.cache_key)
      expect(Rails).to receive(:cache).and_return(rails_cache)

      described_class.fast_current_node_status
    end
  end

  describe '#update_cache!' do
    it 'writes a cache' do
      status = described_class.new

      rails_cache = double
      allow(Rails).to receive(:cache).and_return(rails_cache)

      expect(rails_cache).to receive(:write).with(described_class.cache_key, kind_of(Hash))

      status.update_cache!
    end
  end

  describe '#for_active_secondaries' do
    it 'excludes primaries and disabled nodes' do
      create(:geo_node_status, geo_node: primary)
      create(:geo_node_status, geo_node: create(:geo_node, :secondary, enabled: false))
      enabled_secondary_status = create(:geo_node_status, geo_node: create(:geo_node, :secondary, enabled: true))

      expect(described_class.for_active_secondaries).to match_array([enabled_secondary_status])
    end
  end

  describe '#healthy?' do
    context 'when health is blank' do
      it 'returns true' do
        subject.status_message = ''

        expect(subject.healthy?).to be true
      end
    end

    context 'when health is present' do
      it 'returns true' do
        subject.status_message = GeoNodeStatus::HEALTHY_STATUS

        expect(subject.healthy?).to be true
      end

      it 'returns false' do
        subject.status_message = 'something went wrong'

        expect(subject.healthy?).to be false
      end
    end

    context 'takes outdated? into consideration' do
      it 'return false' do
        subject.status_message = GeoNodeStatus::HEALTHY_STATUS
        subject.updated_at = 61.minutes.ago

        expect(subject.healthy?).to be false
      end

      it 'return false' do
        subject.status_message = 'something went wrong'
        subject.updated_at = 1.minute.ago

        expect(subject.healthy?).to be false
      end
    end
  end

  describe '#outdated?' do
    it 'return true' do
      subject.updated_at = 61.minutes.ago

      expect(subject.outdated?).to be true
    end

    it 'return false' do
      subject.updated_at = 1.minute.ago

      expect(subject.outdated?).to be false
    end
  end

  describe '#status_message' do
    it 'delegates to the HealthCheck' do
      expect(HealthCheck::Utils).to receive(:process_checks).with(['geo']).once

      subject
    end
  end

  describe '#health' do
    it 'returns status message' do
      subject.status_message = 'something went wrong'
      subject.updated_at = 61.minutes.ago

      expect(subject.health).to eq 'something went wrong'
    end
  end

  describe '#projects_count' do
    it 'returns nil on a primary site' do
      stub_current_geo_node(primary)

      expect(subject.projects_count).to be_nil
    end

    it 'returns nil on a secondary site' do
      stub_current_geo_node(secondary)

      create(:geo_project_repository_registry, :synced, project: project_1)
      create(:geo_project_repository_registry, project: project_3)

      expect(subject.projects_count).to be_nil
    end
  end

  describe '#repositories_count' do
    it 'counts the number of project repositories on a primary site' do
      stub_current_geo_node(primary)

      expect(subject.repositories_count).to eq 4
    end

    it 'counts the number of project repository registries on a secondary site' do
      stub_current_geo_node(secondary)

      create(:geo_project_repository_registry, :synced, project: project_1)
      create(:geo_project_repository_registry, project: project_3)

      expect(subject.repositories_count).to eq 2
    end
  end

  describe '#db_replication_lag_seconds' do
    context 'when in a secondary node' do
      before do
        allow(Gitlab::Geo).to receive(:secondary?).and_return(true)
        allow(Gitlab::Geo::HealthCheck).to receive(:new).and_return(geo_health_check)
      end

      context 'when replication is enabled' do
        let(:geo_health_check) { instance_double(Gitlab::Geo::HealthCheck, perform_checks: '', db_replication_lag_seconds: 1000) }

        it 'returns the set replication lag' do
          expect(subject.db_replication_lag_seconds).to eq(1000)
        end
      end

      context 'when replication is disabled' do
        let(:geo_health_check) { instance_double(Gitlab::Geo::HealthCheck, perform_checks: '', db_replication_lag_seconds: nil) }

        before do
          allow(Gitlab::Geo::HealthCheck).to receive(:new).and_return(geo_health_check)
        end

        it 'returns nil' do
          expect(subject.db_replication_lag_seconds).to be_nil
        end
      end
    end

    it "doesn't attempt to set replication lag if primary" do
      stub_current_geo_node(primary)

      expect(subject.db_replication_lag_seconds).to eq(nil)
    end
  end

  describe '#replication_slots_used_count' do
    it 'returns the right number of used replication slots' do
      stub_current_geo_node(primary)
      allow(primary).to receive(:replication_slots_used_count).and_return(1)

      expect(subject.replication_slots_used_count).to eq(1)
    end
  end

  describe '#replication_slots_used_in_percentage' do
    it 'returns 0 when no replication slots are available' do
      expect(subject.replication_slots_used_in_percentage).to eq(0)
    end

    it 'returns 0 when replication slot count is unknown' do
      subject.replication_slots_count = nil

      expect(subject.replication_slots_used_in_percentage).to eq(0)
    end

    it 'returns the right percentage' do
      stub_current_geo_node(primary)
      subject.replication_slots_count = 2
      subject.replication_slots_used_count = 1

      expect(subject.replication_slots_used_in_percentage).to be_within(0.0001).of(50)
    end
  end

  describe '#replication_slots_max_retained_wal_bytes' do
    it 'returns the number of bytes replication slots are using' do
      stub_current_geo_node(primary)
      allow(primary).to receive(:replication_slots_max_retained_wal_bytes).and_return(2.megabytes)

      expect(subject.replication_slots_max_retained_wal_bytes).to eq(2.megabytes)
    end

    it 'handles large values' do
      stub_current_geo_node(primary)
      allow(primary).to receive(:replication_slots_max_retained_wal_bytes).and_return(900.gigabytes)

      expect(subject.replication_slots_max_retained_wal_bytes).to eq(900.gigabytes)
    end
  end

  describe '#last_event_id and #last_event_date' do
    it 'returns nil when no events are available' do
      expect(subject.last_event_id).to be_nil
      expect(subject.last_event_date).to be_nil
    end

    it 'returns the latest event' do
      created_at = Date.today.to_time(:utc)
      event = create(:geo_event_log, created_at: created_at)

      expect(subject.last_event_id).to eq(event.id)
      expect(subject.last_event_date).to eq(created_at)
    end
  end

  describe '#cursor_last_event_id and #cursor_last_event_date' do
    it 'returns nil when no events are available' do
      expect(subject.cursor_last_event_id).to be_nil
      expect(subject.cursor_last_event_date).to be_nil
    end

    it 'returns the latest event ID if secondary' do
      allow(Gitlab::Geo).to receive(:secondary?).and_return(true)
      event = create(:geo_event_log_state)

      expect(subject.cursor_last_event_id).to eq(event.event_id)
    end

    it "doesn't attempt to retrieve cursor if primary" do
      stub_current_geo_node(primary)
      create(:geo_event_log_state)

      expect(subject.cursor_last_event_date).to eq(nil)
      expect(subject.cursor_last_event_id).to eq(nil)
    end
  end

  describe '#version' do
    it { expect(status.version).to eq(Gitlab::VERSION) }
  end

  describe '#revision' do
    it { expect(status.revision).to eq(Gitlab.revision) }
  end

  describe '#[]' do
    it 'returns values for each attribute' do
      expect(subject[:project_repositories_count]).to eq(0)
      expect(subject[:projects_count]).to be_nil
    end

    it 'raises an error for invalid attributes' do
      expect { subject[:testme] }.to raise_error(NoMethodError)
    end
  end

  shared_examples 'timestamp parameters' do |timestamp_column, date_column|
    it 'returns the value it was assigned via UNIX timestamp' do
      now = Time.current.beginning_of_day.utc
      subject.update_attribute(timestamp_column, now.to_i)

      expect(subject.public_send(date_column)).to eq(now)
      expect(subject.public_send(timestamp_column)).to eq(now.to_i)
    end
  end

  describe '#last_successful_status_check_timestamp' do
    it_behaves_like 'timestamp parameters', :last_successful_status_check_timestamp, :last_successful_status_check_at
  end

  describe '#last_event_timestamp' do
    it_behaves_like 'timestamp parameters', :last_event_timestamp, :last_event_date
  end

  describe '#cursor_last_event_timestamp' do
    it_behaves_like 'timestamp parameters', :cursor_last_event_timestamp, :cursor_last_event_date
  end

  describe '#storage_shards' do
    it "returns the current node's shard config" do
      expect(subject[:storage_shards].as_json).to eq(StorageShard.all.as_json)
    end
  end

  describe '#storage_shards_match?' do
    it 'returns false if no shard data is available for secondary' do
      stub_primary_node
      stub_current_geo_node(secondary)

      status = create(:geo_node_status, geo_node: secondary, storage_configuration_digest: 'bc11119c101846c20367fff34ce9fffa9b05aab8')

      expect(status.storage_shards_match?).to be false
    end

    it 'returns true even if no shard data is available for secondary' do
      stub_secondary_node
      stub_current_geo_node(primary)

      status = create(:geo_node_status, geo_node: primary, storage_configuration_digest: 'bc11119c101846c20367fff34ce9fffa9b05aab8')

      expect(status.storage_shards_match?).to be true
    end

    it 'returns false if the storage shards do not match' do
      stub_primary_node
      stub_current_geo_node(secondary)
      create(:geo_node_status, geo_node: primary, storage_configuration_digest: 'aea7849c10b886c202676ff34ce9fdf0940567b8')

      status = create(:geo_node_status, geo_node: secondary, storage_configuration_digest: 'bc11119c101846c20367fff34ce9fffa9b05aab8')

      expect(status.storage_shards_match?).to be false
    end
  end

  describe '#repositories_checked_count' do
    before do
      stub_application_setting(repository_checks_enabled: true)
    end

    context 'current is a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'counts the number of repo checked projects' do
        project_1.update!(last_repository_check_at: 2.minutes.ago)
        project_2.update!(last_repository_check_at: 7.minutes.ago)

        expect(status.repositories_checked_count).to be_nil
      end
    end

    context 'current is a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'returns nil' do
        project_1.update!(last_repository_check_at: 2.minutes.ago)
        project_2.update!(last_repository_check_at: 7.minutes.ago)

        expect(status.repositories_checked_count).to be_nil
      end
    end
  end

  describe '#repositories_checked_failed_count' do
    before do
      stub_application_setting(repository_checks_enabled: true)
    end

    context 'current is a Geo primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'counts the number of repo check failed projects' do
        project_1.update!(last_repository_check_at: 2.minutes.ago, last_repository_check_failed: true)
        project_2.update!(last_repository_check_at: 7.minutes.ago, last_repository_check_failed: false)

        expect(status.repositories_checked_failed_count).to be_nil
      end
    end

    context 'current is a Geo secondary' do
      before do
        stub_current_geo_node(secondary)
      end

      it 'returns nil' do
        project_1.update!(last_repository_check_at: 2.minutes.ago, last_repository_check_failed: true)
        project_2.update!(last_repository_check_at: 7.minutes.ago, last_repository_check_failed: false)

        expect(status.repositories_checked_failed_count).to be_nil
      end
    end
  end

  context 'secondary usage data' do
    shared_examples_for 'a field from secondary_usage_data' do |field|
      describe '#load_secondary_usage_data' do
        it 'loads the latest data from Geo::SecondaryUsageData' do
          data = create(:geo_secondary_usage_data)

          expect(described_class.current_node_status.status[field]).to eq(data.payload[field])
        end

        it 'reports nil if there is no collected data in Geo::SecondaryUsageData' do
          expect(status.status[field]).to be_nil
        end
      end
    end

    described_class.usage_data_fields.each do |field|
      describe "##{field}" do
        it_behaves_like 'a field from secondary_usage_data', field
      end
    end
  end

  context 'Replicator stats' do
    before do
      Project.delete_all

      stub_geo_setting(registry_replication: { enabled: true })
    end

    where(
      replicator: Gitlab::Geo::REPLICATOR_CLASSES
    )

    with_them do
      let(:registry_class) { replicator.registry_class }
      let(:replicable_name) { replicator.replicable_name_plural }
      let(:model_factory) { model_class_factory_name(registry_class) }
      let(:registry_factory) { registry_factory_name(registry_class) }

      context 'replication' do
        context 'on the primary' do
          before do
            stub_current_geo_node(primary)
          end

          describe '#<replicable_name>_count' do
            let(:replicable_count_method) { "#{replicable_name}_count" }

            context 'when replication is enabled' do
              before do
                allow(replicator).to receive(:replication_enabled?).and_return(true)
              end

              context 'when there are replicables' do
                before do
                  create_list(model_factory, 2)
                end

                it 'returns the number of available replicables on primary' do
                  expect(subject.send(replicable_count_method)).to eq(2)
                end
              end

              context 'when there are no replicables' do
                it 'returns 0' do
                  expect(subject.send(replicable_count_method)).to eq(0)
                end
              end
            end

            context 'when replication is disabled' do
              before do
                allow(replicator).to receive(:replication_enabled?).and_return(false)
              end

              context 'and primary checksumming is enabled' do
                before do
                  allow(replicator).to receive(:verification_enabled?).and_return(true)
                end

                context 'when there are replicables' do
                  before do
                    create_list(model_factory, 2)
                  end

                  it 'returns the number of available replicables on primary' do
                    expect(subject.send(replicable_count_method)).to eq(2)
                  end
                end

                context 'when there are no replicables' do
                  it 'returns 0' do
                    expect(subject.send(replicable_count_method)).to eq(0)
                  end
                end
              end

              context 'and primary checksumming is disabled' do
                before do
                  allow(replicator).to receive(:verification_enabled?).and_return(false)

                  create_list(model_factory, 1)
                end

                it 'returns nil' do
                  expect(subject.send(replicable_count_method)).to be_nil
                end
              end
            end
          end
        end

        context 'on the secondary' do
          let(:registry_count_method) { "#{replicable_name}_registry_count" }
          let(:failed_count_method) { "#{replicable_name}_failed_count" }
          let(:synced_count_method) { "#{replicable_name}_synced_count" }
          let(:synced_in_percentage_method) { "#{replicable_name}_synced_in_percentage" }

          before do
            stub_current_geo_node(secondary)
          end

          describe '#<replicable_name>_(registry|synced|failed)_count' do
            context 'when there are registries' do
              before do
                create(registry_factory, :failed)
                create(registry_factory, :failed)
                create(registry_factory, :synced)
              end

              it 'returns the right counts', :aggregate_failures do
                expect(subject.send(registry_count_method)).to eq(3)

                expect(subject.send(failed_count_method)).to eq(2)
                expect(subject.send(synced_count_method)).to eq(1)

                expect(subject.send(synced_in_percentage_method)).to be_within(0.01).of(33.33)
              end
            end

            context 'when there are no registries' do
              it 'returns 0', :aggregate_failures do
                expect(subject.send(registry_count_method)).to eq(0)

                expect(subject.send(failed_count_method)).to eq(0)
                expect(subject.send(synced_count_method)).to eq(0)

                expect(subject.send(synced_in_percentage_method)).to eq(0)
              end
            end
          end
        end
      end

      context 'verification' do
        context 'on the primary' do
          let(:checksummed_count_method) { "#{replicable_name}_checksummed_count" }
          let(:checksum_failed_count_method) { "#{replicable_name}_checksum_failed_count" }

          before do
            stub_current_geo_node(primary)
          end

          context 'when verification is enabled' do
            before do
              allow(replicator).to receive(:verification_enabled?).and_return(true)
            end

            context 'when there are replicables' do
              before do
                create(model_factory, :verification_succeeded)
                create(model_factory, :verification_succeeded)
                create(model_factory, :verification_failed)
              end

              it 'returns the right checksum counts', :aggregate_failures do
                expect(subject.send(checksummed_count_method)).to eq(2)
                expect(subject.send(checksum_failed_count_method)).to eq(1)
              end
            end

            context 'when there are no replicables' do
              it 'returns 0', :aggregate_failures do
                expect(subject.send(checksummed_count_method)).to eq(0)
                expect(subject.send(checksum_failed_count_method)).to eq(0)
              end
            end
          end

          context 'when verification is disabled' do
            before do
              allow(replicator).to receive(:verification_enabled?).and_return(false)
            end

            it 'returns nil', :aggregate_failures do
              expect(subject.send(checksummed_count_method)).to be_nil
              expect(subject.send(checksum_failed_count_method)).to be_nil
            end
          end
        end

        context 'on the secondary' do
          let(:verified_count_method) { "#{replicable_name}_verified_count" }
          let(:verification_failed_count_method) { "#{replicable_name}_verification_failed_count" }
          let(:verified_in_percentage_method) { "#{replicable_name}_verified_in_percentage" }

          before do
            stub_current_geo_node(secondary)
          end

          context 'when verification is enabled' do
            before do
              allow(replicator).to receive(:verification_enabled?).and_return(true)
            end

            context 'when there are replicables' do
              before do
                create(registry_factory, :verification_succeeded)
                create(registry_factory, :verification_succeeded)
                create(registry_factory, :verification_failed)
              end

              it 'returns the right counts and percentage', :aggregate_failures do
                expect(subject.send(verified_count_method)).to eq(2)
                expect(subject.send(verification_failed_count_method)).to eq(1)
                expect(subject.send(verified_in_percentage_method)).to be_within(0.01).of(66.67)
              end
            end

            context 'when there are no replicables' do
              it 'returns 0', :aggregate_failures do
                expect(subject.send(verified_count_method)).to eq(0)
                expect(subject.send(verification_failed_count_method)).to eq(0)
                expect(subject.send(verified_in_percentage_method)).to eq(0)
              end
            end
          end

          context 'when verification is disabled' do
            before do
              allow(replicator).to receive(:verification_enabled?).and_return(false)
            end

            it 'returns nil', :aggregate_failures do
              expect(subject.send(verified_count_method)).to be_nil
              expect(subject.send(verification_failed_count_method)).to be_nil
              expect(subject.send(verified_in_percentage_method)).to eq(0)
            end
          end
        end
      end
    end
  end

  describe '#load_data_from_current_node' do
    context 'on the primary' do
      before do
        stub_current_geo_node(primary)
      end

      it 'does not call JobArtifactRegistryFinder#registry_count' do
        expect_any_instance_of(Geo::JobArtifactRegistryFinder).not_to receive(:registry_count)

        subject
      end
    end

    context 'on the secondary' do
      it 'returns data from the deprecated field if it is not defined in the status field' do
        subject.write_attribute(:projects_count, 10)
        subject.status = {}

        expect(subject.projects_count).to eq 10
      end

      it 'sets data in the new status field' do
        subject.projects_count = 10

        expect(subject.projects_count).to eq 10
      end
    end

    context 'status counters are converted into integers' do
      it 'returns integer value' do
        subject.status = { "projects_count" => "10" }

        expect(subject.projects_count).to eq 10
      end
    end

    context 'status booleans are converted into booleans' do
      it 'returns boolean value' do
        subject.status = { "container_repositories_replication_enabled" => "true" }

        expect(subject.container_repositories_replication_enabled).to eq true
      end
    end

    context 'when a primary metric query times out' do
      before do
        stub_current_geo_node(primary)
        stub_primary_site
        allow(Gitlab::Geo).to receive(:verification_enabled_replicator_classes)
                                .and_return([Geo::JobArtifactReplicator])
        allow(Geo::JobArtifactReplicator).to receive(:primary_total_count)
                                               .and_raise(ActiveRecord::QueryCanceled.new("ERROR: canceling statement due to statement timeout"))
        allow(Geo::JobArtifactReplicator).to receive(:checksummed_count)
                                               .and_return(42)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'fails gracefully and continues collecting other metrics', :aggregate_failures do
        subject # this triggers load_data_from_current_node

        # Failed counts are nil but following metrics are returned normally
        expect(subject.job_artifacts_count).to be_nil
        expect(subject.job_artifacts_checksummed_count).to eq(42)
      end

      it 'calls ErrorTracking for query cancellation errors' do
        subject # this triggers load_data_from_current_node

        expect(Gitlab::ErrorTracking).to have_received(:track_exception)
                                           .with(instance_of(ActiveRecord::QueryCanceled), extra: { metric: 'job_artifacts_count' }).once
      end
    end

    context 'when a secondary metric query times out' do
      before do
        stub_current_geo_node(secondary)
        stub_secondary_site
        allow(Gitlab::Geo).to receive(:replication_enabled_replicator_classes)
                                .and_return([Geo::JobArtifactReplicator])
        allow(Geo::JobArtifactReplicator).to receive(:registry_count)
                                               .and_raise(ActiveRecord::QueryCanceled.new("ERROR: canceling statement due to statement timeout"))
        allow(Geo::JobArtifactReplicator).to receive(:synced_count)
                                               .and_return(42)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'fails gracefully and continues collecting other metrics', :aggregate_failures do
        subject # this triggers load_data_from_current_node

        # Failed counts are nil but following metrics are returned normally
        expect(subject.job_artifacts_count).to be_nil
        expect(subject.job_artifacts_synced_count).to eq(42)
      end

      it 'calls ErrorTracking for query cancellation errors' do
        subject # this triggers load_data_from_current_node

        expect(Gitlab::ErrorTracking).to have_received(:track_exception)
                                           .with(instance_of(ActiveRecord::QueryCanceled), extra: { metric: 'job_artifacts_count' }).once
      end
    end

    context 'when approaching job TTL when called from metrics worker' do
      let(:started_at) { 55.minutes.ago } # With 1 hour TTL and 10 min buffer
      let(:timeout) { 1.hour }

      before do
        stub_current_geo_node(primary)
        stub_primary_site
        allow(Gitlab::Geo).to receive(:verification_enabled_replicator_classes)
                                .and_return([Geo::JobArtifactReplicator])
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_exception).and_call_original
      end

      it 'raises error and stops collecting metrics', :aggregate_failures do
        status = primary.find_or_build_status
        status.started_at = started_at
        status.timeout = timeout

        expect { status.load_data_from_current_node }
          .to raise_error(Geo::Errors::StatusTimeoutError)
      end

      it 'continues collecting metrics when not from metrics worker' do
        status = primary.find_or_build_status
        status.started_at = nil
        status.timeout = nil

        expect { status.load_data_from_current_node }.not_to raise_error
      end

      it 'tracks the error before raising' do
        status = primary.find_or_build_status
        status.started_at = started_at
        status.timeout = timeout

        expect { status.load_data_from_current_node }
          .to raise_error(Geo::Errors::StatusTimeoutError)

        expect(Gitlab::ErrorTracking).to have_received(:track_and_raise_exception)
                                           .with(
                                             instance_of(Geo::Errors::StatusTimeoutError),
                                             extra: hash_including(
                                               time_elapsed: kind_of(Float),
                                               timeout: timeout,
                                               assumed_query_timeout: 10.minutes
                                             )
                                           )
      end
    end
  end
end
