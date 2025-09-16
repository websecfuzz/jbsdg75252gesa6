# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'security policies finder' do
  subject { described_class.new(actor, object, params).execute }

  let(:expected_extra_attrs) { {} }

  shared_examples 'when user does not have developer role in project/group' do
    it 'returns empty collection' do
      is_expected.to be_empty
    end
  end

  describe '#execute' do
    context 'when feature is not licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
        object.add_developer(actor)
      end

      it 'returns empty collection' do
        is_expected.to be_empty
      end
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when configuration is associated to project' do
        # Project not belonging to group
        let_it_be(:object) { create(:project) }

        it_behaves_like 'when user does not have developer role in project/group'

        context 'when user has developer role in the project' do
          before do
            object.add_developer(actor) # rubocop:disable RSpec/BeforeAllRoleAssignment -- let(:actor) is used here
          end

          it 'returns policies with project' do
            is_expected.to match_array([policy.merge(
              {
                config: policy_configuration,
                project: object,
                namespace: nil,
                inherited: false,
                csp: false,
                **expected_extra_attrs
              })])
          end

          context 'when relationship argument is provided as DESCENDANT' do
            let(:relationship) { :descendant }

            it 'returns policies with project only' do
              is_expected.to match_array([policy.merge(
                {
                  config: policy_configuration,
                  project: object,
                  namespace: nil,
                  inherited: false,
                  csp: false,
                  **expected_extra_attrs
                })])
            end
          end

          context 'when include_unscoped is false' do
            let(:include_unscoped) { false }

            context 'when project is not included in the scope' do
              let(:policy_scope) do
                {
                  compliance_frameworks: [],
                  projects: {
                    including: [],
                    excluding: [{
                      id: object.id
                    }]
                  }
                }
              end

              it 'returns empty collection' do
                is_expected.to be_empty
              end
            end

            context 'when project is included in the scope' do
              let(:policy_scope) do
                {
                  compliance_frameworks: [],
                  projects: {
                    including: [{
                      id: object.id
                    }],
                    excluding: []
                  }
                }
              end

              it 'returns policies with project' do
                is_expected.to match_array([policy.merge(
                  {
                    config: policy_configuration,
                    project: object,
                    namespace: nil,
                    inherited: false,
                    csp: false,
                    **expected_extra_attrs
                  })])
              end
            end
          end
        end
      end

      context 'when configuration is associated to namespace' do
        # Project belonging to group
        let_it_be(:object) { create(:project, group: group) }
        let!(:policy_configuration) { nil }

        let!(:group_policy_configuration) do
          create(
            :security_orchestration_policy_configuration,
            :namespace,
            security_policy_management_project: policy_management_project,
            namespace: group,
            experiments: { pipeline_execution_schedule_policy: { enabled: true } }
          )
        end

        it_behaves_like 'when user does not have developer role in project/group'

        context 'when user has developer role in the group' do
          before do
            object.add_developer(actor) # rubocop:disable RSpec/BeforeAllRoleAssignment -- let(:actor) is used here
          end

          context 'when relationship argument is not provided' do
            it 'returns no policies' do
              is_expected.to be_empty
            end
          end

          context 'when relationship argument is provided as INHERITED' do
            let(:relationship) { :inherited }

            it 'returns scan policies for groups only' do
              is_expected.to match_array([policy.merge(
                {
                  config: group_policy_configuration,
                  project: nil,
                  namespace: group,
                  inherited: true,
                  csp: false,
                  **expected_extra_attrs
                })])
            end

            context 'when group is designated as CSP' do
              include Security::PolicyCspHelpers

              before do
                stub_csp_group(group)
              end

              it 'returns scan policies for groups only' do
                is_expected.to match_array([policy.merge(
                  {
                    config: group_policy_configuration,
                    project: nil,
                    namespace: group,
                    inherited: true,
                    csp: true,
                    **expected_extra_attrs
                  })])
              end

              context 'when feature flag "security_policies_csp" is disabled' do
                before do
                  stub_feature_flags(security_policies_csp: false)
                end

                it 'returns policies with csp as false' do
                  is_expected.to match_array([policy.merge(
                    {
                      config: group_policy_configuration,
                      project: nil,
                      namespace: group,
                      inherited: true,
                      csp: false,
                      **expected_extra_attrs
                    })])
                end
              end
            end
          end

          context 'when relationship argument is provided as DESCENDANT' do
            let(:relationship) { :descendant }

            let!(:sub_group) { create(:group, parent: group) }
            let!(:sub_group_policy_configuration) do
              create(
                :security_orchestration_policy_configuration,
                :namespace,
                security_policy_management_project: policy_management_project,
                namespace: sub_group,
                experiments: { pipeline_execution_schedule_policy: { enabled: true } }
              )
            end

            let(:object) { group }

            it 'returns scan policies for descendant groups' do
              is_expected.to match_array(
                [
                  policy.merge(
                    {
                      config: group_policy_configuration,
                      project: nil,
                      namespace: object,
                      inherited: false,
                      csp: false,
                      **expected_extra_attrs
                    }),
                  policy.merge(
                    {
                      config: sub_group_policy_configuration,
                      project: nil,
                      namespace: sub_group,
                      inherited: true,
                      csp: false,
                      **expected_extra_attrs
                    })
                ])
            end
          end
        end
      end

      context 'when configuration is associated to project and namespace' do
        let!(:group_policy_configuration) do
          create(
            :security_orchestration_policy_configuration,
            :namespace,
            security_policy_management_project: policy_management_project,
            namespace: group,
            experiments: { pipeline_execution_schedule_policy: { enabled: true } }
          )
        end

        it_behaves_like 'when user does not have developer role in project/group'

        context 'when user has developer role in the group' do
          before do
            object.add_developer(actor)
          end

          context 'when relationship argument is not provided' do
            it 'returns scan policies for project only' do
              is_expected.to match_array([policy.merge(
                {
                  config: policy_configuration,
                  project: object,
                  namespace: nil,
                  inherited: false,
                  csp: false,
                  **expected_extra_attrs
                })])
            end
          end

          context 'when relationship argument is provided as INHERITED' do
            let(:relationship) { :inherited }

            it 'returns policies defined for both project and namespace' do
              is_expected.to match_array(
                [
                  policy.merge(
                    {
                      config: policy_configuration,
                      project: object,
                      namespace: nil,
                      inherited: false,
                      csp: false,
                      **expected_extra_attrs
                    }),
                  policy.merge(
                    {
                      config: group_policy_configuration,
                      project: nil,
                      namespace: group,
                      inherited: true,
                      csp: false,
                      **expected_extra_attrs
                    })
                ])
            end
          end

          context 'when relationship argument is provided as INHERITED_ONLY' do
            let(:relationship) { :inherited_only }

            it 'returns policies defined for namespace only' do
              is_expected.to match_array([policy.merge(
                {
                  config: group_policy_configuration,
                  project: nil,
                  namespace: group,
                  inherited: true,
                  csp: false,
                  **expected_extra_attrs
                })])
            end
          end

          context 'when relationship argument is provided as DESCENDANT' do
            let(:relationship) { :descendant }

            it 'returns scan policies for descendants only' do
              is_expected.to match_array(
                [
                  policy.merge(
                    {
                      config: policy_configuration,
                      project: object,
                      namespace: nil,
                      inherited: false,
                      csp: false,
                      **expected_extra_attrs
                    })
                ])
            end
          end
        end
      end
    end
  end
end
