# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::MarkAdminBotRunnersAsHosted,
  feature_category: :hosted_runners do
  let!(:admin_bot) { Users::Internal.admin_bot }

  let!(:admin_bot_runner) do
    table(:ci_runners, database: :ci, primary_key: :id)
      .create!(runner_type: 1, creator_id: admin_bot.id)
  end

  let!(:admin_bot_runner2) do
    table(:ci_runners, database: :ci, primary_key: :id)
      .create!(runner_type: 1, creator_id: admin_bot.id)
  end

  let!(:non_admin_bot_runner) { table(:ci_runners, database: :ci, primary_key: :id).create!(runner_type: 1) }

  before do
    allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance).and_return(true)
  end

  subject(:migration) do
    described_class.new(
      start_id: Ci::Runner.minimum(:id),
      end_id: Ci::Runner.maximum(:id),
      batch_table: :ci_runners,
      batch_column: :id,
      sub_batch_size: 100,
      pause_ms: 0,
      connection: ::Ci::ApplicationRecord.connection
    )
  end

  describe '#perform' do
    context 'when on a dedicated instance' do
      it 'marks runners created by admin bot as hosted' do
        expect { migration.perform }.to change { Ci::HostedRunner.count }.by(2)

        expect(Ci::HostedRunner.exists?(runner_id: admin_bot_runner.id)).to be_truthy
        expect(Ci::HostedRunner.exists?(runner_id: admin_bot_runner2.id)).to be_truthy
        expect(Ci::HostedRunner.exists?(runner_id: non_admin_bot_runner.id)).to be_falsey
      end

      it 'does not create duplicate hosted runner records' do
        Ci::HostedRunner.create!(runner_id: admin_bot_runner.id)

        expect { migration.perform }.to change { Ci::HostedRunner.count }.by(1)

        expect(Ci::HostedRunner.exists?(runner_id: admin_bot_runner2.id)).to be_truthy
      end
    end

    context 'when not on a dedicated instance' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:gitlab_dedicated_instance).and_return(false)
      end

      it 'does not create any hosted runner records' do
        expect { migration.perform }.not_to change { Ci::HostedRunner.count }
      end
    end
  end
end
