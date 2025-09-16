# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestBlock, feature_category: :code_review_workflow do
  describe 'associations' do
    it { is_expected.to belong_to(:blocking_merge_request).class_name('MergeRequest') }
    it { is_expected.to belong_to(:blocked_merge_request).class_name('MergeRequest') }
  end

  describe 'validations' do
    subject(:block) { create(:merge_request_block) }

    let(:blocking_mr) { block.blocking_merge_request }
    let(:blocked_mr) { block.blocked_merge_request }
    let(:another_mr) { create(:merge_request) }

    it { is_expected.to validate_presence_of(:blocking_merge_request) }
    it { is_expected.to validate_presence_of(:blocked_merge_request) }

    it 'forbids the blocking MR from being the blocked MR' do
      block.blocking_merge_request = block.blocked_merge_request

      expect(block).not_to be_valid
    end

    it 'allows an MR to block multiple MRs' do
      another_block = described_class.new(
        blocking_merge_request: blocking_mr,
        blocked_merge_request: another_mr
      )

      expect(another_block).to be_valid
    end

    it 'limits the number of blocking MRs to MAX_BLOCKED_BY_COUNT' do
      expect(block).to receive(:blocked_by_count).and_return(MergeRequestBlock::MAX_BLOCKED_BY_COUNT)
      expect(block).not_to be_valid
    end

    it 'limits the number of blocked MRs to MAX_BLOCKS_COUNT' do
      expect(block).to receive(:blocks_count).and_return(MergeRequestBlock::MAX_BLOCKS_COUNT)
      expect(block).not_to be_valid
    end

    it 'allows an MR to be blocked by multiple MRs' do
      another_block = described_class.new(
        blocking_merge_request: another_mr,
        blocked_merge_request: blocked_mr
      )

      expect(another_block).to be_valid
    end

    it 'allows blocks to be intra-project' do
      project = blocking_mr.target_project
      intra_project_mr = create(:merge_request, :rebased, source_project: project, target_project: project)
      block.blocked_merge_request = intra_project_mr

      is_expected.to be_valid
    end

    it 'forbids duplicate blocks' do
      new_block = described_class.new(block.attributes)

      expect(new_block).not_to be_valid
    end

    it 'allows a blocking MR to become blocked' do
      new_block = build(:merge_request_block, blocked_merge_request: block.blocking_merge_request)

      expect(new_block).to be_valid
    end

    it 'allows a blocked MR to become a blocker' do
      new_block = build(:merge_request_block, blocking_merge_request: block.blocked_merge_request)

      expect(new_block).to be_valid
    end
  end

  describe '.with_blocking_mr_ids' do
    let!(:block) { create(:merge_request_block) }
    let!(:other_block) { create(:merge_request_block) }

    subject(:result) { described_class.with_blocking_mr_ids([block.blocking_merge_request_id]) }

    it 'returns blocks with a matching blocking_merge_request_id' do
      is_expected.to contain_exactly(block)
    end

    it 'eager-loads the blocking MRs' do
      association = result.first.association(:blocking_merge_request)
      expect(association.loaded?).to be(true)
    end
  end
end
