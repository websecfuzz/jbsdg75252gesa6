# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::MergeRequestRuleDestroyService do
  let(:rule) { create(:approval_merge_request_rule) }
  let(:user) { create(:user) }

  subject(:result) { described_class.new(rule, user).execute }

  before do
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability)
      .to receive(:allowed?)
      .with(user, :edit_approval_rule, rule)
      .at_least(:once)
      .and_return(can_edit?)
  end

  context 'user cannot edit approval rule' do
    let(:can_edit?) { false }

    it 'returns error status' do
      expect(result[:status]).to eq(:error)
    end
  end

  context 'merge request is merged' do
    let(:merge_request) { create(:merged_merge_request) }
    let(:rule) { build(:approval_merge_request_rule, merge_request: merge_request) }
    let(:can_edit?) { true }

    it 'returns error status' do
      expect(result[:message]).to eq('Merge request already merged')
      expect(result[:status]).to eq(:error)
    end
  end

  context 'user can edit approval rule' do
    let(:can_edit?) { true }

    context 'when rule successfully deleted' do
      it 'returns successful status' do
        expect(result[:status]).to eq(:success)
      end

      it 'tracks delete event via a usage counter' do
        expect(Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter)
          .to receive(:track_approval_rule_deleted_action).once.with(user: user)

        result
      end
    end

    context 'when rule not successfully deleted' do
      before do
        allow(rule).to receive(:destroy).and_return(false)
      end

      it 'returns error status' do
        expect(result[:status]).to eq(:error)
      end

      it 'does not track delete event via a usage counter' do
        expect(Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter)
          .not_to receive(:track_approval_rule_deleted_action)

        result
      end
    end
  end
end
