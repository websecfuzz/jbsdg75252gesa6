# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyScopeChecker, feature_category: :security_policy_management do
  let_it_be_with_refind(:root_group) { create(:group) }
  let_it_be_with_refind(:group) { create(:group, parent: root_group) }
  let_it_be_with_refind(:project) { create(:project, group: group) }
  let_it_be(:compliance_framework) { create(:compliance_framework, namespace: root_group) }

  let(:service) { described_class.new(project: project) }

  shared_examples 'policy scope checker' do
    context 'when policy scope is not set for compliance framework nor project' do
      let(:policy_scope) { {} }

      it { is_expected.to eq true }
    end

    context 'when policy is scoped for compliance framework' do
      let(:policy_scope) do
        {
          compliance_frameworks: [{ id: compliance_framework.id }]
        }
      end

      it "triggers an internal event" do
        expect { policy_applicable }.to trigger_internal_events('check_policy_scope_for_security_policy').with(
          project: project,
          additional_properties: { label: 'compliance_framework' }
        )
      end

      context 'when project does not have compliance framework set' do
        it { is_expected.to eq false }
      end

      context 'when project have compliance framework set' do
        let_it_be(:compliance_framework_project_setting) do
          create(:compliance_framework_project_setting,
            project: project,
            compliance_management_framework: compliance_framework)
        end

        it { is_expected.to eq true }

        context 'when project has multiple compliance frameworks set' do
          let_it_be(:compliance_framework_2) { create(:compliance_framework, :sox, namespace: root_group) }
          let_it_be(:compliance_framework_project_setting) do
            create(:compliance_framework_project_setting,
              project: project,
              compliance_management_framework: compliance_framework_2)
          end

          let(:policy_scope) do
            {
              compliance_frameworks: [{ id: compliance_framework_2.id }]
            }
          end

          it { is_expected.to eq true }
        end

        context 'when policy additionally excludes the project from policy' do
          let(:policy_scope) do
            {
              compliance_frameworks: [{ id: compliance_framework.id }],
              projects: {
                excluding: [{ id: project.id }]
              }
            }
          end

          it { is_expected.to eq false }
        end

        context 'when non-existing compliance framework is set' do
          let(:policy_scope) do
            {
              compliance_frameworks: [{ id: non_existing_record_id }]
            }
          end

          it { is_expected.to eq false }
        end
      end
    end

    context 'when policy is scoped for projects' do
      context 'with including project scope' do
        context 'when included project scope is not matching project id' do
          let(:policy_scope) do
            {
              projects: {
                including: [{ id: non_existing_record_id }]
              }
            }
          end

          it { is_expected.to eq false }

          it "triggers an internal event" do
            expect { policy_applicable }.to trigger_internal_events('check_policy_scope_for_security_policy').with(
              project: project,
              additional_properties: { label: 'project' }
            )
          end
        end

        context 'when included project scope is matching project id' do
          let(:policy_scope) do
            {
              projects: {
                including: [{ id: project.id }]
              }
            }
          end

          it { is_expected.to eq true }

          context 'when additionally excluding project scope is matching project id' do
            let(:policy_scope) do
              {
                projects: {
                  including: [{ id: project.id }],
                  excluding: [{ id: project.id }]
                }
              }
            end

            it { is_expected.to eq false }
          end
        end
      end

      context 'with excluding project scope' do
        context 'when excluding project scope is not matching project id' do
          let(:policy_scope) do
            {
              projects: {
                excluding: [{ id: non_existing_record_id }]
              }
            }
          end

          it { is_expected.to eq true }
        end

        context 'when excluding project scope is matching project id' do
          let(:policy_scope) do
            {
              projects: {
                excluding: [{ id: project.id }]
              }
            }
          end

          it { is_expected.to eq false }
        end
      end
    end

    context 'when policy is scoped for groups' do
      context 'with including group scope' do
        context 'when included group scope is not matching group id' do
          let(:policy_scope) do
            {
              groups: {
                including: [{ id: non_existing_record_id }]
              }
            }
          end

          it { is_expected.to eq false }

          it "triggers an internal event" do
            expect { policy_applicable }.to trigger_internal_events('check_policy_scope_for_security_policy').with(
              project: project,
              additional_properties: { label: 'group' }
            )
          end
        end

        context 'when included group scope is matching project distant ancestor group id' do
          let(:policy_scope) do
            {
              groups: {
                including: [{ id: root_group.id }]
              }
            }
          end

          it { is_expected.to eq true }
        end

        context 'when included group scope is matching project direct ancestor group id' do
          let(:policy_scope) do
            {
              groups: {
                including: [{ id: group.id }]
              }
            }
          end

          it { is_expected.to eq true }

          context 'when additionally excluding group scope is matching project ancestor group id' do
            let(:policy_scope) do
              {
                groups: {
                  including: [{ id: group.id }],
                  excluding: [{ id: group.id }]
                }
              }
            end

            it { is_expected.to eq false }
          end
        end
      end

      context 'with excluding group scope' do
        context 'when excluding group scope is not matching project ancestor group id' do
          let(:policy_scope) do
            {
              groups: {
                excluding: [{ id: non_existing_record_id }]
              }
            }
          end

          it { is_expected.to eq true }
        end

        context 'when excluding group scope is matching project ancestor group id' do
          let(:policy_scope) do
            {
              groups: {
                excluding: [{ id: group.id }]
              }
            }
          end

          it { is_expected.to eq false }
        end
      end

      context 'with excluding parent group and including subgroup' do
        let(:policy_scope) do
          {
            groups: {
              excluding: [{ id: root_group.id }],
              including: [{ id: group.id }]
            }
          }
        end

        it { is_expected.to eq false }
      end

      context 'with excluding subgroup and including parent group' do
        let(:policy_scope) do
          {
            groups: {
              excluding: [{ id: group.id }],
              including: [{ id: root_group.id }]
            }
          }
        end

        it { is_expected.to eq false }
      end
    end
  end

  describe '#policy_applicable?' do
    let(:policy) { { policy_scope: policy_scope } }

    subject(:policy_applicable) { service.policy_applicable?(policy) }

    context 'when policy is empty' do
      let(:policy) { {} }

      it { is_expected.to eq false }
    end

    it_behaves_like 'policy scope checker'
  end

  describe '#security_policy_applicable?' do
    let(:policy) { create(:security_policy, scope: policy_scope) }

    subject(:policy_applicable) { service.security_policy_applicable?(policy) }

    context 'when policy is empty' do
      let(:policy) { nil }

      it { is_expected.to eq false }
    end

    it_behaves_like 'policy scope checker'
  end
end
