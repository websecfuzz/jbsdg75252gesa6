# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyDiff::Diff, feature_category: :security_policy_management do
  let(:diff) { described_class.new }

  describe '#to_h' do
    it 'returns a hash with diff and rules_diff' do
      diff.add_policy_field(:field1, 'old', 'new')

      expect(diff.to_h).to eq({
        diff: { field1: { from: 'old', to: 'new' } },
        rules_diff: { created: [], updated: [], deleted: [] }
      })
    end
  end

  describe '#needs_refresh?' do
    it 'returns true when policy_scope is changed' do
      diff.add_policy_field(:policy_scope, nil, {})

      expect(diff.needs_refresh?).to be true
    end

    it 'returns true when enabled is changed' do
      diff.add_policy_field(:enabled, nil, true)

      expect(diff.needs_refresh?).to be true
    end

    it 'returns true when schedules is changed' do
      diff.add_policy_field(:schedules, nil, true)

      expect(diff.needs_refresh?).to be true
    end

    it 'returns true when rules are created' do
      diff.add_created_rule({})

      expect(diff.needs_refresh?).to be true
    end

    it 'returns true when rules are deleted' do
      diff.add_deleted_rule(create(:approval_policy_rule))

      expect(diff.needs_refresh?).to be true
    end

    it 'returns false when no relevant changes are made' do
      diff.add_policy_field(:field1, 'old', 'new')

      expect(diff.needs_refresh?).to be false
    end
  end

  describe '#status_changed?' do
    it 'returns true when enabled is changed' do
      diff.add_policy_field(:enabled, false, true)

      expect(diff.status_changed?).to be true
    end

    it 'returns false when enabled is not changed' do
      diff.add_policy_field(:field1, 'old', 'new')

      expect(diff.status_changed?).to be false
    end
  end

  describe '#scope_changed?' do
    it 'returns true when policy_scope is changed' do
      diff.add_policy_field(:policy_scope, nil, {})

      expect(diff.scope_changed?).to be true
    end

    it 'returns false when policy_scope is not changed' do
      diff.add_policy_field(:field1, 'old', 'new')

      expect(diff.scope_changed?).to be false
    end
  end

  describe '#content_changed?' do
    it 'returns true when content is changed' do
      diff.add_policy_field(:content, nil, {})

      expect(diff.content_changed?).to be true
    end

    it 'returns false when content is not changed' do
      diff.add_policy_field(:field1, 'old', 'new')

      expect(diff.content_changed?).to be false
    end
  end

  describe '#content_project_changed?' do
    it 'returns true when project in the content is changed from nil' do
      diff.add_policy_field(:content, nil, { include: [{ project: 'new' }] })

      expect(diff.content_project_changed?).to be true
    end

    it 'returns true when project in the content is changed from other project' do
      diff.add_policy_field(:content, { include: [{ project: 'old' }] }, { include: [{ project: 'new' }] })

      expect(diff.content_project_changed?).to be true
    end

    it 'returns false when other field in the content is not changed' do
      diff.add_policy_field(:content, { include: [{ project: 'old', file: 'old' }] },
        { include: [{ project: 'old', file: 'new' }] })

      expect(diff.content_project_changed?).to be false
    end

    it 'returns false when other field is changed' do
      diff.add_policy_field(:field1, 'old', 'new')

      expect(diff.content_project_changed?).to be false
    end
  end

  describe '#any_changes?' do
    let(:diff) { described_class.new }

    context 'when there are no changes' do
      it 'returns false' do
        expect(diff.any_changes?).to be false
      end
    end

    context 'when there are changes in diff' do
      before do
        diff.add_policy_field(:enabled, false, true)
      end

      it 'returns true' do
        expect(diff.any_changes?).to be true
      end
    end

    context 'when there are changes in rules_diff' do
      before do
        allow(diff.rules_diff).to receive(:any_changes?).and_return(true)
      end

      it 'returns true' do
        expect(diff.any_changes?).to be true
      end
    end

    context 'when there are changes in both diff and rules_diff' do
      before do
        diff.add_policy_field(:enabled, false, true)
        allow(diff.rules_diff).to receive(:any_changes?).and_return(true)
      end

      it 'returns true' do
        expect(diff.any_changes?).to be true
      end
    end
  end

  describe '#needs_rules_refresh?' do
    it 'returns true when actions is changed' do
      diff.add_policy_field(:actions,
        [{ type: 'require_approval', approvals_required: 1, user_approvers: %w[user_approver] }],
        [{ type: 'require_approval', approvals_required: 1, role_approvers: %w[user_approver] }]
      )

      expect(diff.needs_rules_refresh?).to be true
    end

    it 'returns true when fallback_behavior is changed' do
      diff.add_policy_field(:fallback_behavior, {}, { fail: "open" })

      expect(diff.needs_rules_refresh?).to be true
    end

    it 'returns true when rules_diff.updated is changed' do
      diff.add_updated_rule(create(:approval_policy_rule), { branches: ['main'] }, { branches: %w[main feature] })

      expect(diff.needs_rules_refresh?).to be true
    end

    it 'returns false for no changes in concerned fields' do
      diff.add_policy_field(:field1, 'old', 'new')

      expect(diff.needs_rules_refresh?).to be false
    end
  end

  describe '#needs_complete_rules_refresh?' do
    subject(:needs_complete_rules_refresh?) { diff.needs_complete_rules_refresh? }

    context 'when actions have not changed' do
      it { is_expected.to be_falsey }
    end

    context 'when actions have changed' do
      before do
        diff.add_policy_field(:actions, from_actions, to_actions)
      end

      context 'when approval actions count remains the same' do
        let(:from_actions) do
          [
            { type: 'require_approval', user_approvers: ['user1'] },
            { type: 'send_bot_message', enabled: false }
          ]
        end

        let(:to_actions) do
          [
            { type: 'require_approval', user_approvers: ['user2'] },
            { type: 'send_bot_message', enabled: false }
          ]
        end

        it { is_expected.to be_falsey }
      end

      context 'when approval action is added' do
        let(:from_actions) do
          [
            { type: 'send_bot_message', enabled: false }
          ]
        end

        let(:to_actions) do
          [
            { type: 'require_approval', user_approvers: ['user1'] },
            { type: 'send_bot_message', enabled: false }
          ]
        end

        it { is_expected.to be_truthy }
      end

      context 'when approval action is removed' do
        let(:from_actions) do
          [
            { type: 'require_approval', user_approvers: ['user1'] },
            { type: 'send_bot_message', enabled: false }
          ]
        end

        let(:to_actions) do
          [
            { type: 'send_bot_message', enabled: false }
          ]
        end

        it { is_expected.to be_truthy }
      end

      context 'when actions are nil' do
        let(:from_actions) { nil }
        let(:to_actions) { [{ type: 'require_approval', user_approvers: ['user1'] }] }

        it { is_expected.to be_truthy }
      end

      context 'when multiple approval actions are changed' do
        let(:from_actions) do
          [
            { type: 'require_approval', user_approvers: ['user1'] },
            { type: 'require_approval', user_approvers: ['user2'] }
          ]
        end

        let(:to_actions) do
          [
            { type: 'require_approval', user_approvers: ['user3'] }
          ]
        end

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '.from_json' do
    let(:diff) do
      {
        'enabled' => { 'from' => false, 'to' => true },
        'policy_scope' => { 'from' => nil, 'to' => {} }
      }.deep_symbolize_keys
    end

    let(:rules_diff) do
      {
        'created' => [{ 'id' => 1 }],
        'updated' => [{ 'id' => 2, 'from' => { 'name' => 'Old Rule' }, 'to' => { 'name' => 'Updated Rule' } }],
        'deleted' => [{ 'id' => 3, 'from' => { 'name' => 'Deleted Rule' }, 'to' => nil }]
      }.deep_symbolize_keys
    end

    subject(:from_json) { described_class.from_json(diff, rules_diff) }

    it 'sets the diff attribute correctly' do
      expect(from_json.diff.keys).to contain_exactly(:enabled, :policy_scope)
      expect(from_json.diff[:enabled]).to be_a(Security::SecurityOrchestrationPolicies::PolicyDiff::FieldDiff)
      expect(from_json.diff[:policy_scope]).to be_a(Security::SecurityOrchestrationPolicies::PolicyDiff::FieldDiff)
    end

    it 'sets the rules_diff attribute correctly' do
      expect(from_json.rules_diff).to be_a(Security::SecurityOrchestrationPolicies::PolicyDiff::RulesDiff)
    end

    context 'when rules_diff is nil' do
      let(:rules_diff) { nil }

      it 'creates an empty RulesDiff' do
        expect(from_json.rules_diff).to be_a(Security::SecurityOrchestrationPolicies::PolicyDiff::RulesDiff)
        expect(from_json.rules_diff.to_h).to eq({ created: [], updated: [], deleted: [] })
      end
    end

    context 'when diff is empty' do
      let(:diff) { {} }

      it 'creates an empty diff attribute' do
        expect(from_json.diff).to be_empty
      end
    end
  end
end
