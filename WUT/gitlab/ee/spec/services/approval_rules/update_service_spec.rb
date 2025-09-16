# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApprovalRules::UpdateService, feature_category: :code_review_workflow do
  let(:project) { create(:project) }
  let(:user) { project.creator }
  let(:approval_rule) { target.approval_rules.create!(name: 'foo', approvals_required: 2) }
  let(:container) { project }

  shared_examples 'editable' do
    let(:new_approvers) { create_list(:user, 2) }
    let(:new_groups) { create_list(:group, 2, :private) }

    context 'basic update action' do
      let(:result) do
        described_class.new(approval_rule, user, {
          name: 'security',
          approvals_required: 1,
          user_ids: new_approvers.map(&:id),
          group_ids: new_groups.map(&:id)
        }).execute
      end

      it 'updates approval, excluding non-eligible users and groups' do
        expect(result[:status]).to eq(:success)
        rule = result[:rule]

        expect(rule.name).to eq('security')
        expect(rule.approvals_required).to eq(1)
        expect(rule.users).to be_empty
        expect(rule.groups).to be_empty
      end

      it 'tracks update event via a usage counter' do
        expect(Gitlab::UsageDataCounters::MergeRequestActivityUniqueCounter)
          .to receive(:track_approval_rule_edited_action).once.with(user: user)

        result
      end
    end

    context 'when some users and groups are eligible' do
      before do
        container.add_reporter new_approvers.first
        new_groups.first.add_guest user
      end

      it 'creates and includes eligible users and groups' do
        result = described_class.new(approval_rule, user, {
          name: 'security',
          approvals_required: 1,
          user_ids: new_approvers.map(&:id),
          group_ids: new_groups.map(&:id)
        }).execute

        expect(result[:status]).to eq(:success)

        rule = result[:rule]

        expect(rule.name).to eq('security')
        expect(rule.approvals_required).to eq(1)
        expect(rule.users).to contain_exactly(new_approvers.first)
        expect(rule.groups).to contain_exactly(new_groups.first)
      end
    end

    context 'when existing groups are inaccessible to user' do
      let(:private_accessible_group) { create(:group, :private) }
      let(:private_inaccessible_group) { create(:group, :private) }
      let(:new_group) { create(:group) }

      before do
        approval_rule.groups = [private_accessible_group, private_inaccessible_group]
        private_accessible_group.add_guest user
      end

      context 'when remove_hidden_groups is false' do
        it 'preserves inaccessible groups' do
          result = described_class.new(approval_rule, user, {
            remove_hidden_groups: false,
            group_ids: [new_group.id]
          }).execute

          expect(result[:status]).to eq(:success)

          rule = result[:rule]

          expect(rule.groups).to contain_exactly(private_inaccessible_group, new_group)
        end
      end

      context 'when remove_hidden_groups is not specified' do
        it 'removes inaccessible groups' do
          result = described_class.new(approval_rule, user, {
            group_ids: [new_group.id]
          }).execute

          expect(result[:status]).to eq(:success)

          rule = result[:rule]

          expect(rule.groups).to contain_exactly(private_inaccessible_group, new_group)
        end
      end

      context 'when remove_hidden_groups is true' do
        it 'removes inaccessible groups' do
          result = described_class.new(approval_rule, user, {
            remove_hidden_groups: true,
            group_ids: [new_group.id]
          }).execute

          expect(result[:status]).to eq(:success)

          rule = result[:rule]

          expect(rule.groups).to contain_exactly(new_group)
        end
      end
    end

    context 'when validation fails' do
      it 'returns error message' do
        result = described_class.new(approval_rule, user, {
          name: nil,
          approvals_required: 1
        }).execute

        expect(result[:status]).to eq(:error)
      end
    end

    context 'when user does not have right to edit' do
      let(:user) { create(:user) }

      it 'returns error message' do
        result = described_class.new(approval_rule, user, {
          approvals_required: 1
        }).execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to include('Prohibited')
      end
    end
  end

  shared_examples_for 'invokes compliance standards adherence workers' do
    it 'invokes ComplianceManagement::Standards::Gitlab::AtLeastTwoApprovalsWorker' do
      expect(::ComplianceManagement::Standards::Gitlab::AtLeastTwoApprovalsWorker)
        .to receive(:perform_async).with({ 'project_id' => approval_rule.project.id, 'user_id' => user.id })
                                   .and_call_original

      described_class.new(approval_rule, user, {
        name: 'security',
        approvals_required: 1
      }).execute
    end

    it 'invokes ComplianceManagement::Standards::Soc2::AtLeastOneNonAuthorApprovalWorker' do
      expect(::ComplianceManagement::Standards::Soc2::AtLeastOneNonAuthorApprovalWorker)
        .to receive(:perform_async).with({ 'project_id' => approval_rule.project.id, 'user_id' => user.id })
                                   .and_call_original

      described_class.new(approval_rule, user, {
        name: 'security',
        approvals_required: 1
      }).execute
    end
  end

  context 'when target is project' do
    let(:target) { project }

    it_behaves_like "editable"

    it_behaves_like "invokes compliance standards adherence workers"

    context 'when protected_branch_ids param is present' do
      let(:protected_branch) { create(:protected_branch, project: target) }

      subject do
        described_class.new(
          approval_rule,
          user,
          protected_branch_ids: [protected_branch.id]
        ).execute
      end

      context 'and multiple approval rules is enabled' do
        before do
          stub_licensed_features(multiple_approval_rules: true)
        end

        it 'associates the approval rule to the protected branch' do
          expect(subject[:status]).to eq(:success)
          expect(subject[:rule].protected_branches).to eq([protected_branch])
        end

        context 'but user cannot administer project' do
          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :admin_project, target).and_return(false)
          end

          it 'does not associate the approval rule to the protected branch' do
            expect(subject[:status]).to eq(:success)
            expect(subject[:rule].protected_branches).to be_empty
          end
        end

        context 'but protected branch is for another project' do
          let(:another_project) { create(:project) }
          let(:protected_branch) { create(:protected_branch, project: another_project) }

          it 'does not associate the approval rule to the protected branch' do
            expect(subject[:status]).to eq(:success)
            expect(subject[:rule].protected_branches).to be_empty
          end
        end
      end

      context 'and multiple approval rules is disabled' do
        it 'does not associate the approval rule to the protected branch' do
          expect(subject[:status]).to eq(:success)
          expect(subject[:rule].protected_branches).to be_empty
        end
      end
    end

    describe 'audit events' do
      let_it_be(:user) { create(:user) }
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:destination) { create(:external_audit_event_destination, group: parent_group) }
      let_it_be(:project) { create(:project, creator: user, group: parent_group) }
      let_it_be(:approver) { create(:user, name: 'Batman') }
      let_it_be(:group) { create(:group, name: 'Justice League') }
      let_it_be(:new_approver) { create(:user, name: 'Spiderman') }
      let_it_be(:new_group) { create(:group, name: 'Avengers') }

      let(:approval_rule) do
        create(:approval_project_rule,
          name: 'Gotham',
          project: target,
          approvals_required: 2,
          users: [approver],
          groups: [group]
        )
      end

      before do
        parent_group.add_owner(user)
        project.add_reporter approver
        project.add_reporter new_approver
      end

      context 'when licensed' do
        before do
          stub_licensed_features(audit_events: true)
          stub_licensed_features(external_audit_events: true)
        end

        context 'when rule update operation succeeds', :request_store do
          it 'logs an audit event' do
            expect do
              described_class.new(approval_rule, user, approvals_required: 1).execute
            end.to change { AuditEvent.count }.by(1)
          end

          it_behaves_like 'sends correct event type in audit event stream' do
            let_it_be(:event_type) { 'update_approval_rules' }
            subject { described_class.new(approval_rule, user, approvals_required: 1).execute }
          end

          it 'audits the number of required approvals change' do
            described_class.new(approval_rule, user, approvals_required: 1).execute

            expect(AuditEvent.last).to have_attributes(
              details: hash_including(change: 'number of required approvals', from: 2, to: 1)
            )
          end

          it 'audits the group addition to approval group' do
            described_class.new(approval_rule, user, group_ids: [group.id, new_group.id]).execute

            expect(AuditEvent.last.details[:custom_message]).to eq(
              "Added Group Avengers to approval group on Gotham rule"
            )
          end

          it 'audits the group removal from approval group' do
            described_class.new(approval_rule, user, group_ids: []).execute

            expect(AuditEvent.last.details[:custom_message]).to eq(
              "Removed Group Justice League from approval group on Gotham rule"
            )
          end

          it 'audits the user addition to approval group' do
            described_class.new(approval_rule, user, user_ids: [approver.id, new_approver.id]).execute

            expect(AuditEvent.last.details[:custom_message]).to eq(
              "Added User Spiderman to approval group on Gotham rule"
            )
          end

          it 'audits the user removal from approval group' do
            described_class.new(approval_rule, user, user_ids: []).execute

            expect(AuditEvent.last.details[:custom_message]).to eq(
              "Removed User Batman from approval group on Gotham rule"
            )
          end

          it 'audits the name change of a approval rule' do
            described_class.new(approval_rule, user, name: 'Avenger').execute

            expect(AuditEvent.last).to have_attributes(
              author: user,
              entity: project,
              target_id: approval_rule.id,
              target_type: approval_rule.class.name,
              target_details: approval_rule.name,
              details: include(custom_message: "Changed name from Gotham to Avenger")
            )
          end

          context 'when changing target branch' do
            before do
              stub_licensed_features(multiple_approval_rules: true)
            end

            let(:protected_branch) { create(:protected_branch, project: target) }

            context 'when new target branch is applied' do
              subject(:execute) do
                described_class.new(
                  approval_rule,
                  user,
                  protected_branch_ids: [protected_branch.id]
                ).execute
              end

              it 'calls auditor with correct args' do
                expect(::Gitlab::Audit::Auditor).to receive(:audit).ordered.and_call_original

                expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
                  hash_including(
                    author: user,
                    name: 'update_approval_rules',
                    scope: project,
                    target: approval_rule,
                    message: "Changed target branch to #{protected_branch.name} branch"
                  )
                ).ordered

                execute
              end
            end

            context 'when target branch is changed to all branches' do
              before do
                approval_rule.update!(protected_branches: [protected_branch])
              end

              subject(:execute) do
                described_class.new(
                  approval_rule,
                  user,
                  protected_branch_ids: []
                ).execute
              end

              it 'calls auditor with correct args' do
                expect(::Gitlab::Audit::Auditor).to receive(:audit).ordered.and_call_original

                expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
                  hash_including(
                    author: user,
                    name: 'update_approval_rules',
                    scope: project,
                    target: approval_rule,
                    message: "Changed target branch to all branches"
                  )
                ).ordered

                execute
              end
            end

            context 'when target branch is changed to all protected branches' do
              subject(:execute) do
                described_class.new(
                  approval_rule,
                  user,
                  applies_to_all_protected_branches: true
                ).execute
              end

              it 'calls auditor with correct args' do
                expect(::Gitlab::Audit::Auditor).to receive(:audit).ordered.and_call_original

                expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
                  hash_including(
                    author: user,
                    name: 'update_approval_rules',
                    scope: project,
                    target: approval_rule,
                    message: "Changed target branch to all protected branches"
                  )
                ).ordered

                execute
              end
            end

            context 'when target branch is changed from all protected branches to a protected branch' do
              before do
                approval_rule.update!(applies_to_all_protected_branches: true)
              end

              subject(:execute) do
                described_class.new(
                  approval_rule,
                  user,
                  protected_branch_ids: [protected_branch.id],
                  applies_to_all_protected_branches: false
                ).execute
              end

              it 'calls auditor with correct args' do
                expect(::Gitlab::Audit::Auditor).to receive(:audit).ordered.and_call_original

                expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
                  hash_including(
                    author: user,
                    name: 'update_approval_rules',
                    scope: project,
                    target: approval_rule,
                    message: "Changed target branch to #{protected_branch.name} branch"
                  )
                ).ordered

                execute
              end
            end
          end
        end

        context 'when rule update operation fails', :request_store do
          context 'when user is added to approval group' do
            it 'does not log any audit event' do
              expect do
                described_class.new(approval_rule, user,
                  user_ids: [approver.id, new_approver.id],
                  approvals_required: ApprovalRuleLike::APPROVALS_REQUIRED_MAX + 1).execute
              end.not_to change { AuditEvent.count }
            end
          end

          context 'when user is removed from approval group' do
            it 'does not log any audit event' do
              expect do
                described_class.new(approval_rule, user,
                  user_ids: [],
                  approvals_required: ApprovalRuleLike::APPROVALS_REQUIRED_MAX + 1).execute
              end.not_to change { AuditEvent.count }
            end
          end

          it 'does not log any audit event' do
            allow(approval_rule).to receive(:update).and_return(false)

            expect do
              described_class.new(approval_rule, user, approvals_required: 1).execute
            end.not_to change { AuditEvent.count }
          end
        end
      end

      context 'when not licensed' do
        before do
          stub_licensed_features(
            admin_audit_log: false,
            audit_events: false,
            extended_audit_events: false
          )
        end

        it 'does not log any audit event' do
          expect do
            described_class.new(approval_rule, user, approvals_required: 1).execute
          end.not_to change { AuditEvent.count }
        end
      end
    end
  end

  context 'when target is merge request' do
    let(:target) { create(:merge_request, source_project: project, target_project: project) }

    it_behaves_like "editable"
    it_behaves_like "invokes compliance standards adherence workers"
  end

  context 'when target is a group' do
    let(:target) { create(:group) }
    let(:container) { target }
    let(:group_user) { create(:user) }
    let(:user) { group_user }

    before do
      target.add_owner(group_user)
    end

    it_behaves_like "editable"

    it 'does not invoke ComplianceManagement::Standards::Gitlab::AtLeastTwoApprovalsWorker' do
      expect(::ComplianceManagement::Standards::Gitlab::AtLeastTwoApprovalsWorker).not_to receive(:perform_async)

      described_class.new(approval_rule, user, {
        name: 'security',
        approvals_required: 1
      }).execute
    end

    it 'does not invoke ComplianceManagement::Standards::Soc2::AtLeastOneNonAuthorApprovalWorker' do
      expect(::ComplianceManagement::Standards::Soc2::AtLeastOneNonAuthorApprovalWorker).not_to receive(:perform_async)

      described_class.new(approval_rule, user, {
        name: 'security',
        approvals_required: 1
      }).execute
    end
  end
end
