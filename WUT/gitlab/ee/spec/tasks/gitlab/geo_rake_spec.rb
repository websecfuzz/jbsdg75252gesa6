# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:geo rake tasks', :geo, :silence_stdout, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  before do
    Rake.application.rake_require 'tasks/gitlab/geo'
    # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
    # is not allowed within a transaction but all RSpec tests run inside of a transaction.
    stub_batch_counter_transaction_open_check
    stub_licensed_features(geo: true)
  end

  describe 'gitlab:geo:check_replication_verification_status' do
    let(:run_task) { run_rake_task('gitlab:geo:check_replication_verification_status') }
    let!(:current_node) { create(:geo_node) }
    let!(:geo_node_status) { build(:geo_node_status, :healthy, geo_node: current_node) }

    around do |example|
      example.run
    rescue SystemExit
    end

    before do
      allow(GeoNodeStatus).to receive(:current_node_status).and_return(geo_node_status)
      allow(Gitlab.config.geo.registry_replication).to receive(:enabled).and_return(true)

      allow(Gitlab::Geo::GeoNodeStatusCheck).to receive(:replication_verification_complete?)
                                                  .and_return(complete)
    end

    context 'when replication is up-to-date' do
      let(:complete) { true }

      it 'prints a success message' do
        expect { run_task }.to output(/SUCCESS - Replication is up-to-date/).to_stdout
      end
    end

    context 'when replication is not up-to-date' do
      let(:complete) { false }

      it 'prints an error message' do
        expect { run_task }.to output(/ERROR - Replication is not up-to-date/).to_stdout
      end

      it 'exits with a 1' do
        expect { run_task }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end
  end

  describe 'gitlab:geo:prevent_updates_to_primary_site' do
    let(:run_task) do
      run_rake_task('gitlab:geo:prevent_updates_to_primary_site')
    end

    context 'on a primary site' do
      before do
        stub_primary_node
      end

      it 'enables maintenance mode and drains non-Geo queues' do
        expect(Gitlab::Geo::GeoTasks).to receive(:enable_maintenance_mode)
        expect(Gitlab::Geo::GeoTasks).to receive(:drain_non_geo_queues)

        run_task
      end
    end

    context 'on a secondary site' do
      it 'aborts' do
        stub_secondary_node

        expect { run_task }.to abort_execution.with_message(/This command is only available on a primary node/)
      end
    end

    context 'on a site without Geo enabled' do
      it 'aborts' do
        expect { run_task }.to abort_execution.with_message(/This command is only available on a primary node/)
      end
    end
  end

  describe 'gitlab:geo:wait_until_replicated_and_verified' do
    let(:run_task) do
      run_rake_task('gitlab:geo:wait_until_replicated_and_verified')
    end

    context 'on a primary site' do
      it 'aborts' do
        stub_primary_node

        expect { run_task }.to abort_execution.with_message(/This command is only available on a secondary node/)
      end
    end

    context 'on a secondary site' do
      before do
        stub_secondary_node
      end

      it 'waits until everything is replicated and verified' do
        expect(Gitlab::Geo::GeoTasks).to receive(:wait_until_replicated_and_verified)

        run_task
      end
    end

    context 'on a site without Geo enabled' do
      it 'aborts' do
        expect { run_task }.to abort_execution.with_message(/This command is only available on a secondary node/)
      end
    end
  end
end
