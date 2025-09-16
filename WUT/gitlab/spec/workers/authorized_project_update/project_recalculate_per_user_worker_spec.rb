# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuthorizedProjectUpdate::ProjectRecalculatePerUserWorker, feature_category: :permissions do
  include ExclusiveLeaseHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  subject(:worker) { described_class.new }

  it 'is labeled as high urgency' do
    expect(described_class.get_urgency).to eq(:high)
  end

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it 'has an option to reschedule once if deduplicated' do
    expect(described_class.get_deduplication_options).to include(
      { if_deduplicated: :reschedule_once, including_scheduled: true }
    )
  end

  include_examples 'an idempotent worker' do
    let(:job_args) { [project.id, user.id] }

    it 'does not change authorizations when run twice' do
      project.add_developer(user)

      user.project_authorizations.delete_all

      expect { worker.perform(project.id, user.id) }.to change { project.project_authorizations.reload.size }.by(1)
      expect { worker.perform(project.id, user.id) }.not_to change { project.project_authorizations.reload.size }
    end
  end

  describe '#perform' do
    it 'does not fail if the project does not exist' do
      expect do
        worker.perform(non_existing_record_id, user.id)
      end.not_to raise_error
    end

    it 'does not fail if the user does not exist' do
      expect do
        worker.perform(project.id, non_existing_record_id)
      end.not_to raise_error
    end

    it 'calls AuthorizedProjectUpdate::ProjectRecalculatePerUserService' do
      expect_next_instance_of(AuthorizedProjectUpdate::ProjectRecalculatePerUserService, project, user) do |service|
        expect(service).to receive(:execute)
      end

      worker.perform(project.id, user.id)
    end
  end
end
