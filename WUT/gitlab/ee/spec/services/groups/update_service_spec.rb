# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::UpdateService, '#execute', feature_category: :groups_and_projects do
  let!(:user) { create(:user) }
  let!(:group) { create(:group, :public) }

  context 'audit events' do
    let(:audit_event_params) do
      {
        author_id: user.id,
        entity_id: group.id,
        entity_type: 'Group',
        details: {
          author_name: user.name,
          author_class: user.class.name,
          target_id: group.id,
          target_type: 'Group',
          target_details: group.full_path
        }
      }
    end

    before do
      group.add_owner(user)
    end

    describe '#visibility' do
      include_examples 'audit event logging' do
        let(:fail_condition!) do
          allow(group).to receive(:save).and_return(false)
        end

        let(:operation_params) { { visibility_level: Gitlab::VisibilityLevel::PRIVATE } }

        let(:attributes) do
          audit_event_params.tap do |param|
            param[:details].merge!(
              change: 'visibility',
              from: 'Public',
              to: 'Private',
              custom_message: "Changed visibility from Public to Private",
              event_name: 'group_visibility_level_updated'
            )
          end
        end
      end
    end

    describe 'ip restrictions' do
      context 'when IP restrictions were changed' do
        before do
          group.add_owner(user)
        end

        include_examples 'audit event logging' do
          let(:fail_condition!) do
            allow(group).to receive(:save).and_return(false)
          end

          let(:operation_params) { { ip_restriction_ranges: '192.168.0.0/24,10.0.0.0/8' } }

          let(:attributes) do
            audit_event_params.tap do |param|
              param[:details].merge!(
                event_name: 'ip_restrictions_changed',
                custom_message: "Group IP restrictions updated from '' to '192.168.0.0/24,10.0.0.0/8'"
              )
            end
          end
        end
      end
    end

    describe 'allowed email domain' do
      context 'when allowed email domains were changed' do
        before do
          group.add_owner(user)
        end

        include_examples 'audit event logging' do
          let(:fail_condition!) do
            allow(group).to receive(:save).and_return(false)
          end

          let(:operation_params) { { allowed_email_domains_list: 'abcd.com,test.com' } }

          let(:attributes) do
            audit_event_params.tap do |param|
              param[:details].merge!(
                event_name: 'allowed_email_domain_updated',
                custom_message: "Allowed email domain names updated from '' to 'abcd.com,test.com'"
              )
            end
          end
        end
      end
    end

    def operation(update_params = operation_params)
      update_group(group, user, **update_params)
    end
  end

  context 'sub group' do
    let(:parent_group) { create :group }
    let(:group) { create :group, parent: parent_group }

    subject { update_group(group, user, { name: 'new_sub_group_name' }) }

    before do
      parent_group.add_owner(user)
    end

    include_examples 'sends streaming audit event'
  end

  describe 'changing file_template_project_id' do
    let(:group) { create(:group) }
    let(:valid_project) { create(:project, namespace: group) }
    let(:user) { create(:user) }

    def update_file_template_project_id(id)
      update_group(group, user, file_template_project_id: id)
    end

    before do
      stub_licensed_features(custom_file_templates_for_namespace: true)
    end

    context 'as a group maintainer' do
      before do
        group.add_maintainer(user)
      end

      it 'does not allow a project to be removed' do
        group.update_columns(file_template_project_id: valid_project.id)

        expect(update_file_template_project_id(nil)).to be_falsy
        expect(group.errors[:file_template_project_id]).to include('cannot be changed by you')
      end

      it 'does not allow a project to be set' do
        expect(update_file_template_project_id(valid_project.id)).to be_falsy
        expect(group.errors[:file_template_project_id]).to include('cannot be changed by you')
      end
    end

    context 'as a group owner' do
      before do
        group.add_owner(user)
      end

      it 'allows a project to be removed' do
        group.update_columns(file_template_project_id: valid_project.id)

        expect(update_file_template_project_id(nil)).to be_truthy
        expect(group.reload.file_template_project_id).to be_nil
      end

      it 'allows a valid project to be set' do
        expect(update_file_template_project_id(valid_project.id)).to be_truthy
        expect(group.reload.file_template_project_id).to eq(valid_project.id)
      end

      it 'does not allow a project outwith the group to be set' do
        invalid_project = create(:project)

        expect(update_file_template_project_id(invalid_project.id)).to be_falsy
        expect(group.errors[:file_template_project_id]).to include('is invalid')
      end

      it 'does not allow a non-existent project to be set' do
        invalid_project = create(:project)
        invalid_project.destroy!

        expect(update_file_template_project_id(invalid_project.id)).to be_falsy
        expect(group.errors[:file_template_project_id]).to include('is invalid')
      end

      context 'in a subgroup' do
        let(:parent_group) { create(:group) }
        let(:hidden_project) { create(:project, :private, namespace: parent_group) }
        let(:group) { create(:group, parent: parent_group) }

        before do
          group.update!(parent: parent_group)
        end

        it 'does not allow a project the group owner cannot see to be set' do
          expect(update_file_template_project_id(hidden_project.id)).to be_falsy
          expect(group.reload.file_template_project_id).to be_nil
        end

        it 'allows a project in the subgroup to be set' do
          expect(update_file_template_project_id(valid_project.id)).to be_truthy
          expect(group.reload.file_template_project_id).to eq(valid_project.id)
        end
      end
    end
  end

  context 'repository_size_limit assignment as Bytes' do
    let_it_be(:group) { create(:group, repository_size_limit: 0) }
    let_it_be(:admin_user) { create(:admin) }

    context 'when the user is an admin and admin mode is enabled', :enable_admin_mode do
      context 'when the param is present' do
        let(:opts) { { repository_size_limit: '100' } }

        it 'converts from MiB to Bytes' do
          update_group(group, admin_user, opts)

          expect(group.reload.repository_size_limit).to eql(100 * 1024 * 1024)
        end
      end

      context 'when the param is an empty string' do
        let(:opts) { { repository_size_limit: '' } }

        it 'assigns a nil value' do
          update_group(group, admin_user, opts)

          expect(group.reload.repository_size_limit).to be_nil
        end
      end
    end

    context 'when the user is an admin and admin mode is disabled' do
      let(:opts) { { repository_size_limit: '100' } }

      it 'does not update the limit' do
        update_group(group, admin_user, opts)

        expect(group.reload.repository_size_limit).to eq(0)
      end
    end

    context 'when the user is not an admin' do
      let(:opts) { { repository_size_limit: '100' } }

      it 'does not persist the limit' do
        update_group(group, user, opts)

        expect(group.reload.repository_size_limit).to eq(0)
      end
    end
  end

  context 'setting ip_restriction' do
    let(:group) { create(:group) }

    subject { update_group(group, user, params) }

    before do
      stub_licensed_features(group_ip_restriction: true)
    end

    context 'when ip_restriction already exists' do
      let!(:ip_restriction) { IpRestriction.create!(group: group, range: '10.0.0.0/8') }

      context 'empty ip restriction param' do
        let(:params) { { ip_restriction_ranges: '' } }

        it 'deletes ip restriction' do
          expect(group.ip_restrictions.first.range).to eql('10.0.0.0/8')

          subject

          expect(group.reload.ip_restrictions.count).to eq(0)
        end
      end
    end
  end

  context 'setting allowed email domain' do
    let(:group) { create(:group, :private) }
    let(:user) { create(:user, email: 'admin@gitlab.com') }

    subject { update_group(group, user, params) }

    before do
      stub_licensed_features(group_allowed_email_domains: true)
    end

    context 'when allowed_email_domain already exists' do
      let!(:allowed_domain) { create(:allowed_email_domain, group: group, domain: 'gitlab.com') }

      context 'allowed_email_domains_list param is not specified' do
        let(:params) { {} }

        it 'does not call EE::AllowedEmailDomains::UpdateService#execute' do
          expect_any_instance_of(EE::AllowedEmailDomains::UpdateService).not_to receive(:execute)

          subject
        end
      end

      context 'allowed_email_domains_list param is blank' do
        let(:params) { { allowed_email_domains_list: '' } }

        context 'as a group owner' do
          before do
            group.add_owner(user)
          end

          it 'calls EE::AllowedEmailDomains::UpdateService#execute' do
            expect_any_instance_of(EE::AllowedEmailDomains::UpdateService).to receive(:execute)

            subject
          end

          it 'update is successful' do
            expect(subject).to eq(true)
          end

          it 'deletes existing allowed_email_domain record' do
            expect { subject }.to change { group.reload.allowed_email_domains.size }.from(1).to(0)
          end
        end

        context 'as a normal user' do
          it 'calls EE::AllowedEmailDomains::UpdateService#execute' do
            expect_any_instance_of(EE::AllowedEmailDomains::UpdateService).to receive(:execute)

            subject
          end

          it 'update is not successful' do
            expect(subject).to eq(false)
          end

          it 'registers an error' do
            subject

            expect(group.errors[:allowed_email_domains]).to include('cannot be changed by you')
          end

          it 'does not delete existing allowed_email_domain record' do
            expect { subject }.not_to change { group.reload.allowed_email_domains.size }
          end
        end
      end
    end
  end

  context 'updating protected params' do
    let(:attrs) { { shared_runners_minutes_limit: 1000, extra_shared_runners_minutes_limit: 100 } }

    context 'as an admin' do
      let(:user) { create(:admin) }

      it 'updates the attributes' do
        update_group(group, user, attrs)

        expect(group.shared_runners_minutes_limit).to eq(1000)
        expect(group.extra_shared_runners_minutes_limit).to eq(100)
      end
    end

    context 'as a regular user' do
      it 'ignores the attributes' do
        update_group(group, user, attrs)

        expect(group.shared_runners_minutes_limit).to be_nil
        expect(group.extra_shared_runners_minutes_limit).to be_nil
      end
    end
  end

  context 'updating insight_attributes.project_id param' do
    let(:attrs) { { insight_attributes: { project_id: private_project.id } } }

    shared_examples 'successful update of the Insights project' do
      it 'updates the Insights project' do
        update_group(group, user, attrs)

        expect(group.insight.project).to eq(private_project)
      end
    end

    shared_examples 'ignorance of the Insights project ID' do
      it 'ignores the Insights project ID' do
        update_group(group, user, attrs)

        expect(group.insight).to be_nil
      end
    end

    context 'when project is not in the group' do
      let(:private_project) { create(:project, :private) }

      context 'when user can read the project' do
        before do
          private_project.add_maintainer(user)
        end

        it_behaves_like 'ignorance of the Insights project ID'
      end

      context 'when user cannot read the project' do
        it_behaves_like 'ignorance of the Insights project ID'
      end
    end

    context 'when project is in the group' do
      let(:private_project) { create(:project, :private, group: group) }

      context 'when user can read the project' do
        before do
          private_project.add_maintainer(user)
        end

        it_behaves_like 'successful update of the Insights project'
      end

      context 'when user cannot read the project' do
        it_behaves_like 'ignorance of the Insights project ID'
      end
    end
  end

  context 'updating analytics_dashboards_pointer_attributes.target_project_id param' do
    let(:attrs) { { analytics_dashboards_pointer_attributes: { target_project_id: private_project.id } } }
    let(:private_project) do
      create(:project, :private, group: group).tap do |project|
        project.add_maintainer(user)
      end
    end

    it 'updates the Analytics Dashboards pointer project' do
      update_group(group, user, attrs)

      expect(group.analytics_dashboards_pointer.target_project).to eq(private_project)
    end

    context 'when passing a bogus target project' do
      let(:attrs) { { analytics_dashboards_pointer_attributes: { target_project_id: create(:project).id } } }

      it 'fails' do
        success = update_group(group, user, attrs)

        expect(success).to eq(false)
        expect(group).to be_invalid
      end
    end

    context 'when pointer project is empty' do
      let(:existing_pointer) do
        create(:analytics_dashboards_pointer, namespace: group, target_project: private_project)
      end

      let(:attrs) { { analytics_dashboards_pointer_attributes: { id: existing_pointer.id, target_project_id: '' } } }

      it 'removes pointer project' do
        update_group(group, user, attrs)

        expect(group.reload.analytics_dashboards_pointer).to eq(nil)
      end
    end
  end

  context 'updating `max_personal_access_token_lifetime` param' do
    subject { update_group(group, user, attrs) }

    let!(:group) do
      create(:group_with_managed_accounts, :public, max_personal_access_token_lifetime: 1)
    end

    let(:limit) { 10 }
    let(:attrs) { { max_personal_access_token_lifetime: limit } }

    shared_examples_for 'it does not call the update lifetime service' do
      it "doesn't call the update lifetime service" do
        expect(::PersonalAccessTokens::Groups::UpdateLifetimeService).not_to receive(:new)

        subject
      end
    end

    it 'updates the attribute' do
      expect { subject }.to change { group.reload.max_personal_access_token_lifetime }.from(1).to(10)
    end

    context 'when the group does not enforce managed accounts' do
      it_behaves_like 'it does not call the update lifetime service'
    end

    context 'when the group enforces managed accounts' do
      before do
        allow(group).to receive(:enforced_group_managed_accounts?).and_return(true)
      end

      context 'without `personal_access_token_expiration_policy` licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: false)
        end

        it_behaves_like 'it does not call the update lifetime service'
      end

      context 'with personal_access_token_expiration_policy licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: true)
        end

        context 'when `max_personal_access_token_lifetime` is updated to null value' do
          let(:limit) { nil }

          it_behaves_like 'it does not call the update lifetime service'
        end

        context 'when `max_personal_access_token_lifetime` is updated to a non-null value' do
          it 'executes the update lifetime service' do
            expect_next_instance_of(::PersonalAccessTokens::Groups::UpdateLifetimeService, group) do |service|
              expect(service).to receive(:execute)
            end

            subject
          end
        end
      end
    end
  end

  context 'updating user cap params' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_refind(:group) do
      create(:group, :public,
        namespace_settings: create(:namespace_settings, seat_control: :user_cap, new_user_signups_cap: 1))
    end

    let_it_be(:member) { create(:group_member, :awaiting, :maintainer, source: group) }

    before_all do
      group.add_owner(user)
    end

    subject(:update_cap) { update_group(group, user, attrs) }

    context 'when disabling the setting' do
      let(:attrs) { { seat_control: :off, new_user_signups_cap: nil } }

      it 'auto approves pending members' do
        update_cap

        expect(member.reload).to be_active
      end
    end

    context 'when disabling the setting and leaving the new_user_signups_cap value' do
      let(:attrs) { { seat_control: :off } }

      it 'auto approves pending members' do
        update_cap

        expect(member.reload).to be_active
      end
    end

    context 'when not disabling the setting' do
      let(:attrs) { { new_user_signups_cap: 25 } }

      it 'does not auto approve pending members' do
        update_cap

        expect(member.reload).to be_awaiting
      end
    end

    context 'when switching to block seat overages', :sidekiq_inline do
      let(:attrs) { { seat_control: :block_overages, new_user_signups_cap: nil } }

      it 'removes all pending members' do
        update_cap

        expect(group.members.map(&:user_id)).to eq([user.id])
      end
    end
  end

  context 'when updating duo_features_enabled' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group, :public) }
    let(:params) { { duo_features_enabled: false } }

    context 'as a normal user' do
      before_all do
        group.add_maintainer(user)
      end

      it 'does not change settings' do
        expect { update_group(group, user, params) }
          .not_to(change { group.namespace_settings.duo_features_enabled })
      end
    end

    context 'as a group owner' do
      before_all do
        group.add_owner(user)
      end

      it 'changes settings' do
        expect { update_group(group, user, params) }
          .to(change { group.namespace_settings.duo_features_enabled }.to(false))
      end

      context 'group has subgroups' do
        let(:subgroup) { create(:group, parent: group) }

        it 'runs worker that sets subgroup duo_features_enabled to match group', :sidekiq_inline do
          subgroup.namespace_settings.update!(duo_features_enabled: true)

          update_group(group, user, params)

          expect(subgroup.reload.namespace_settings.reload.duo_features_enabled).to eq false
        end
      end
    end
  end

  context 'when updating lock_duo_features_enabled' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group, :public) }

    let(:params) { { lock_duo_features_enabled: true } }

    context 'as a normal user' do
      before_all do
        group.add_maintainer(user)
      end

      it 'does not change settings' do
        expect { update_group(group, user, params) }
         .not_to(change { group.namespace_settings.lock_duo_features_enabled })
      end
    end

    context 'as a group owner' do
      before_all do
        group.add_owner(user)
      end

      it 'changes the group settings' do
        expect { update_group(group, user, params) }
          .to(change { group.namespace_settings.lock_duo_features_enabled }.to(true))
      end
    end
  end

  context 'when updating duo_availability' do
    let_it_be(:group) { create(:group, :public) }
    let_it_be(:service_account) { create(:user) }
    let_it_be_with_refind(:integration) { create(:amazon_q_integration, instance: false, group: group) }

    using RSpec::Parameterized::TableSyntax

    where(:duo_availability, :amazon_q_connected, :expected_result) do
      'never_on'    | true  | true
      'never_on'    | false | false
      'default_off' | true  | false
      'default_off' | false | false
    end

    with_them do
      let(:params) { { duo_availability: duo_availability } }

      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(amazon_q_connected)
        ::Ai::Setting.instance.update!(amazon_q_service_account_user_id: service_account.id)
      end

      it 'calls the service when conditions are met' do
        if expected_result
          expect_next_instance_of(::Ai::ServiceAccountMemberRemoveService, user, group, service_account) do |service|
            expect(service).to receive(:execute)
          end
        else
          expect(::Ai::ServiceAccountMemberRemoveService).not_to receive(:new)
        end

        update_group(group, user, params)
      end
    end

    context 'when updating Amazon Q auto_review_enabled' do
      let(:params) { { duo_availability: 'default_on', amazon_q_auto_review_enabled: true } }

      it 'does not change Amazon Q integration' do
        expect(PropagateIntegrationWorker).not_to receive(:perform_async)
        expect { update_group(group, user, params) }.not_to change {
          group.amazon_q_integration.reload.auto_review_enabled
        }
      end

      context 'when Amazon Q is connected' do
        before do
          allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
        end

        it 'changes Amazon Q integration values' do
          expect(PropagateIntegrationWorker).to receive(:perform_async).with(integration.id)
          expect { update_group(group, user, params) }.to change {
            group.amazon_q_integration.reload.auto_review_enabled
          }.from(false).to(true)
        end

        context 'when amazon_q_auto_review_enabled is nil' do
          let(:params) { { duo_availability: 'default_on', amazon_q_auto_review_enabled: nil } }

          it 'does not update auto_review_enabled setting' do
            expect { update_group(group, user, params) }.not_to change {
              group.amazon_q_integration.reload.auto_review_enabled
            }
          end
        end
      end
    end

    context 'for duo workflow group authorization' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:connected?).and_return(duo_workflow_connected)
        Ai::Setting.instance.update!(duo_workflow_service_account_user_id: service_account.id)
      end

      where(:duo_availability, :duo_workflow_connected, :expected_result) do
        'never_on'    | true  | true
        'never_on'    | false | false
        'default_off' | true  | false
        'default_off' | false | false
      end

      with_them do
        let(:params) { { duo_availability: duo_availability } }

        it 'calls the service when conditions are met' do
          if expected_result
            expect_next_instance_of(::Ai::ServiceAccountMemberRemoveService, user, group, service_account) do |service|
              expect(service).to receive(:execute)
            end
          else
            expect(::Ai::ServiceAccountMemberRemoveService).not_to receive(:new)
          end

          update_group(group, user, params)
        end
      end
    end
  end

  context 'when ai settings change', :saas do
    before do
      allow(Gitlab).to receive(:com?).and_return(true)
      stub_ee_application_setting(should_check_namespace_plan: true)
      stub_licensed_features(ai_features: true)
      group.add_owner(user)
    end

    context 'when experiment_features_enabled changes' do
      let(:params) { { experiment_features_enabled: true } }

      it 'publishes an event after successful update' do
        expect do
          update_group(group, user, params)
        end.to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
          .with(group_id: group.id)
      end

      context 'when update fails' do
        before do
          allow(group).to receive(:save).and_return(false)
        end

        it 'does not publish an event' do
          expect do
            update_group(group, user, params)
          end.not_to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
        end
      end
    end

    context 'when experiment_features setting does not change' do
      let(:params) { { experiment_features_enabled: false } }

      before do
        group.namespace_settings.update!(experiment_features_enabled: false)
      end

      it 'does not publish an event' do
        expect do
          update_group(group, user, params)
        end.not_to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
      end
    end
  end

  context 'when updating web_based_commit_signing_enabled' do
    let(:service) do
      described_class.new(group, user, web_based_commit_signing_enabled: web_based_commit_signing_enabled)
    end

    let(:repositories_web_based_commit_signing) { true }
    let(:web_based_commit_signing_enabled) { true }

    before do
      stub_saas_features(repositories_web_based_commit_signing: repositories_web_based_commit_signing)
      group.add_owner(user)
    end

    shared_examples_for 'enqueues job' do
      it 'enqueues a job' do
        expect(Namespaces::CascadeWebBasedCommitSigningEnabledWorker).to receive(:perform_async).with(group.id)
        service.execute
      end
    end

    shared_examples_for 'does not enqueue job' do
      it 'does not enqueue a job' do
        expect(Namespaces::CascadeWebBasedCommitSigningEnabledWorker).not_to receive(:perform_async).with(group.id)
        service.execute
      end
    end

    shared_examples_for 'ignoring web_based_commit_signing_enabled' do
      it 'deletes the parameter' do
        expect(::NamespaceSettings::AssignAttributesService).to receive(:new).with(
          user,
          group,
          hash_not_including(:web_based_commit_signing_enabled)
        ).twice.and_call_original

        service.execute
      end

      it_behaves_like 'does not enqueue job'
    end

    context 'when the repositories_web_based_commit_signing feature is not available' do
      let(:repositories_web_based_commit_signing) { false }

      it_behaves_like 'ignoring web_based_commit_signing_enabled'
    end

    context 'when the use_web_based_commit_signing_enabled feature flag is not enabled' do
      before do
        stub_feature_flags(use_web_based_commit_signing_enabled: false)
      end

      it_behaves_like 'ignoring web_based_commit_signing_enabled'
    end

    context 'when enabling web_based_commit_signing_enabled' do
      it_behaves_like 'enqueues job'

      context 'and already enabled' do
        before do
          group.namespace_settings.update!(web_based_commit_signing_enabled: true)
          group.reload
        end

        it_behaves_like 'does not enqueue job'
      end
    end

    context 'when disabling web_based_commit_signing_enabled' do
      let(:web_based_commit_signing_enabled) { false }

      it_behaves_like 'enqueues job'

      context 'and already disabled' do
        before do
          group.namespace_settings.update!(web_based_commit_signing_enabled: false)
          group.reload
        end

        it_behaves_like 'does not enqueue job'
      end
    end
  end

  context 'remove_dormant_members feature handling' do
    shared_examples 'does not schedule worker' do |worker|
      it "does not schedule #{worker} worker" do
        expect(worker).not_to receive(:perform_with_capacity)

        update_group(group.reload, user, params)
      end
    end

    context 'when remove_dormant_members feature changes' do
      context 'when remove_dormant_members feature is initially disabled and is enabled in the params' do
        let(:params) { { remove_dormant_members: true } }
        let(:worker) { Namespaces::RemoveDormantMembersWorker }

        it 'schedules Namespaces::RemoveDormantMembersWorker workers' do
          expect(worker).to receive(:perform_with_capacity).once

          update_group(group, user, params)
        end
      end

      context 'when remove_dormant_members feature is initially disabled and the update to enable it fails' do
        let(:params) { { remove_dormant_members: true } }

        before do
          allow(group).to receive(:save).and_return(false)
        end

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end

      context 'when remove_dormant_members feature is initially enabled and is disabled in the params' do
        let(:params) { { remove_dormant_members: false } }

        before do
          group.namespace_settings.update!(remove_dormant_members: true)
        end

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end
    end

    context 'when remove_dormant_members feature does not change' do
      context 'when remove_dormant_members setting is disabled and a value of false is passed for it in the params' do
        let(:params) { { remove_dormant_members: false } }

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end

      context 'when remove_dormant_members feature is initially disabled and another group setting is changed' do
        let(:params) { { experiment_features_enabled: true } }

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end

      context 'when remove_dormant_members feature is already enabled and another group setting is changed' do
        let(:params) { { experiment_features_enabled: true } }

        before do
          group.namespace_settings.update!(remove_dormant_members: true)
        end

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end

      context 'when the remove_dormant_members feature is already enabled and its param has a value of true' do
        let(:params) { { remove_dormant_members: true } }

        before do
          group.namespace_settings.update!(remove_dormant_members: true)
        end

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end
    end
  end

  def update_group(group, user, opts)
    Groups::UpdateService.new(group, user, opts).execute
  end
end
