# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicySetting, feature_category: :security_policy_management, type: :model do
  let_it_be(:organization) { create(:organization) }

  subject(:settings) { build(:security_policy_settings, organization: organization) }

  describe 'associations' do
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization') }
    it { is_expected.to belong_to(:csp_namespace).optional.class_name('Group') }
  end

  describe 'validations' do
    describe 'csp_namespace' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:child_group) { create(:group, parent: parent_group) }

      it 'can be assigned a top level group' do
        settings.update!(csp_namespace: parent_group)
        expect(settings.csp_namespace).to eq(parent_group)
      end

      it 'cannot be assigned a child group' do
        expect do
          settings.update!(csp_namespace: child_group)
        end.to raise_error(ActiveRecord::RecordInvalid,
          'Validation failed: CSP namespace must be a top level Group')
      end

      it 'cannot be assigned a user namespace' do
        user = create(:user, :with_namespace)
        settings.csp_namespace_id = user.namespace.id

        expect(settings).to be_invalid
        expect(settings.errors[:csp_namespace]).to include('must be a group')
      end
    end
  end

  describe '.for_organization' do
    subject(:for_organization) { described_class.for_organization(organization) }

    context 'when an entry does not exist' do
      it 'creates an entry' do
        expect { for_organization }.to change { described_class.count }.by(1)
      end

      it 'sets default attributes' do
        expect(for_organization).to have_attributes(csp_namespace_id: nil)
      end
    end

    context 'when an entry exists' do
      let_it_be(:settings) do
        create(:security_policy_settings, organization: organization, csp_namespace: create(:group))
      end

      it 'does not create a new entry' do
        expect { for_organization }.not_to change { described_class.count }
      end

      it 'returns the existing entry' do
        expect(for_organization).to eq(settings)
      end
    end
  end

  describe '#csp_enabled?' do
    include Security::PolicyCspHelpers

    subject { settings.csp_enabled?(group) }

    let(:group) { top_level_group }
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: top_level_group) }

    it { is_expected.to be(false) }

    context 'when the group is designated as a CSP group' do
      before do
        settings.update!(csp_namespace: top_level_group)
      end

      it { is_expected.to be(true) }

      context 'when on GitLab.com', :saas do
        it { is_expected.to be(false) }
      end

      context 'when feature flag "security_policies_csp" is disabled' do
        before do
          stub_feature_flags(security_policies_csp: false)
        end

        it { is_expected.to be(false) }
      end

      context 'with subgroup and feature flag "security_policies_csp" enabled for the root ancestor' do
        let(:group) { subgroup }

        before do
          stub_feature_flags(security_policies_csp: top_level_group)
        end

        it { is_expected.to be(true) }
      end

      context 'with feature flag "security_policies_csp" enabled for :instance' do
        before do
          stub_feature_flags(security_policies_csp: Feature::FlipperGitlabInstance.new)
        end

        it { is_expected.to be(true) }
      end
    end
  end

  describe '#trigger_security_policies_updates' do
    subject(:policy_settings) { create(:security_policy_settings, organization: organization) }

    let_it_be(:old_group) { create(:group) }
    let_it_be(:new_group) { create(:group) }
    let_it_be(:old_configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: old_group)
    end

    let_it_be(:new_configuration) do
      create(:security_orchestration_policy_configuration, :namespace, namespace: new_group)
    end

    context 'when csp_namespace_id changes from nil to a group' do
      it 'schedules SyncScanPoliciesWorker for the new group' do
        expect(Security::RecreateOrchestrationConfigurationWorker).not_to receive(:perform_async)
        expect(Security::SyncScanPoliciesWorker).to receive(:perform_async)
          .with(new_configuration.id, { 'force_resync' => true })

        policy_settings.update!(csp_namespace: new_group)
      end

      context 'when new group has no security orchestration policy configuration' do
        let(:group_without_config) { create(:group) }

        it 'does not schedule any workers' do
          expect(Security::RecreateOrchestrationConfigurationWorker).not_to receive(:perform_async)
          expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async)

          policy_settings.update!(csp_namespace: group_without_config)
        end
      end
    end

    context 'when csp_namespace_id changes from one group to another' do
      before do
        policy_settings.update!(csp_namespace: old_group)
      end

      it 'schedules both workers for old and new groups' do
        expect(Security::RecreateOrchestrationConfigurationWorker).to receive(:perform_async)
          .with(old_configuration.id)
        expect(Security::SyncScanPoliciesWorker).to receive(:perform_async)
          .with(new_configuration.id, { 'force_resync' => true })

        policy_settings.update!(csp_namespace: new_group)
      end

      context 'when old group has no security orchestration policy configuration' do
        let(:old_group_without_config) { create(:group) }

        before do
          policy_settings.update!(csp_namespace: old_group_without_config)
        end

        it 'only schedules SyncScanPoliciesWorker for the new group' do
          expect(Security::RecreateOrchestrationConfigurationWorker).not_to receive(:perform_async)
          expect(Security::SyncScanPoliciesWorker).to receive(:perform_async)
            .with(new_configuration.id, { 'force_resync' => true })

          policy_settings.update!(csp_namespace: new_group)
        end
      end

      context 'when new group has no security orchestration policy configuration' do
        let(:new_group_without_config) { create(:group) }

        it 'only schedules RecreateOrchestrationConfigurationWorker for the old group' do
          expect(Security::RecreateOrchestrationConfigurationWorker).to receive(:perform_async)
            .with(old_configuration.id)
          expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async)

          policy_settings.update!(csp_namespace: new_group_without_config)
        end
      end
    end

    context 'when csp_namespace_id changes from a group to nil' do
      before do
        policy_settings.update!(csp_namespace: old_group)
      end

      it 'only schedules RecreateOrchestrationConfigurationWorker for the old group' do
        expect(Security::RecreateOrchestrationConfigurationWorker).to receive(:perform_async)
          .with(old_configuration.id)
        expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async)

        policy_settings.update!(csp_namespace: nil)
      end

      context 'when old group has no security orchestration policy configuration' do
        let(:old_group_without_config) { create(:group) }

        before do
          policy_settings.update!(csp_namespace: old_group_without_config)
        end

        it 'does not schedule any workers' do
          expect(Security::RecreateOrchestrationConfigurationWorker).not_to receive(:perform_async)
          expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async)

          policy_settings.update!(csp_namespace: nil)
        end
      end
    end

    context 'when csp_namespace_id does not change' do
      before do
        policy_settings.update!(csp_namespace: old_group)
      end

      it 'does not schedule any workers when updating other attributes' do
        expect(Security::RecreateOrchestrationConfigurationWorker).not_to receive(:perform_async)
        expect(Security::SyncScanPoliciesWorker).not_to receive(:perform_async)

        # Trigger an update without changing csp_namespace_id
        policy_settings.touch
      end
    end
  end
end
