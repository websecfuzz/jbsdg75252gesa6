# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Checkpoint, feature_category: :duo_workflow do
  def microsecond_precision_timestamp(time)
    time.change(nsec: (time.nsec / 1000) * 1000)
  end

  let_it_be(:checkpoint1) do
    timestamp = microsecond_precision_timestamp(3.days.ago)
    create(:duo_workflows_checkpoint, thread_ts: timestamp.to_s, created_at: timestamp)
  end

  let_it_be(:checkpoint2) do
    timestamp = microsecond_precision_timestamp(2.days.ago)
    create(:duo_workflows_checkpoint, thread_ts: timestamp.to_s, created_at: timestamp)
  end

  let_it_be(:write1) do
    create(:duo_workflows_checkpoint_write, thread_ts: checkpoint1.thread_ts, workflow: checkpoint1.workflow)
  end

  let_it_be(:write2) do
    create(:duo_workflows_checkpoint_write, thread_ts: checkpoint1.thread_ts, workflow: checkpoint1.workflow)
  end

  it { is_expected.to validate_presence_of(:thread_ts) }
  it { is_expected.to validate_presence_of(:checkpoint) }
  it { is_expected.to validate_presence_of(:metadata) }

  it "touches workflow on save" do
    workflow = create(:duo_workflows_workflow)
    expect(workflow.created_at).to eq(workflow.updated_at)

    create(:duo_workflows_checkpoint, workflow: workflow)
    expect(workflow.updated_at).to be > workflow.created_at
  end

  describe '.ordered_with_writes' do
    it 'returns checkpoints ordered by thread_ts with writes included' do
      result = described_class.ordered_with_writes

      expect(result.to_a).to eq([checkpoint2, checkpoint1])
      expect(result[0].association(:checkpoint_writes)).to be_loaded
    end
  end

  describe '.with_checkpoint_writes' do
    it 'returns checkpoint, including checkpoint_writes' do
      result = described_class.with_checkpoint_writes

      expect(result.to_a).to match_array([checkpoint2, checkpoint1])
      expect(result[0].association(:checkpoint_writes)).to be_loaded
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:namespace).optional }

    describe '#checkpoint_writes' do
      let_it_be(:write3) { create(:duo_workflows_checkpoint_write, thread_ts: checkpoint1.thread_ts) }
      let_it_be(:write4) { create(:duo_workflows_checkpoint_write, workflow: checkpoint2.workflow) }

      it 'returns writes for the same workflow having same thread_ts' do
        expect(checkpoint1.checkpoint_writes).to match_array([write1, write2])
      end

      it 'has many checkpoint_writes' do
        is_expected.to have_many(:checkpoint_writes)
          .conditions(Ai::DuoWorkflows::CheckpointWrite.arel_table[:workflow_id]
            .eq(described_class.arel_table[:workflow_id]))
          .with_foreign_key(:thread_ts)
          .with_primary_key(:thread_ts)
          .inverse_of(:checkpoint)
      end
    end
  end

  describe '.find' do
    it 'finds by single id using find_by_id' do
      expect(described_class).to receive(:find_by_id).with(checkpoint1.id.first)
      described_class.find(checkpoint1.id.first)
    end

    it 'falls back to super for array arguments' do
      expect(
        described_class.find([checkpoint1.id.first, checkpoint1.created_at])
      ).to eq(checkpoint1)
    end
  end

  describe '#to_global_id' do
    it 'returns a GlobalID with the first id element' do
      gid = checkpoint1.to_global_id
      expect(gid).to be_a(GlobalID)
      expect(gid.model_id).to eq(checkpoint1.id.first.to_s)
    end
  end
end
