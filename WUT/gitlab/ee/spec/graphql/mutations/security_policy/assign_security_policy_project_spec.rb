# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::SecurityPolicy::AssignSecurityPolicyProject, feature_category: :security_policy_management do
  include GraphqlHelpers
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let_it_be(:owner) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: owner.namespace) }
    let_it_be(:policy_project) { create(:project) }
    let_it_be(:policy_project_id) { GitlabSchema.id_from_object(policy_project) }

    let(:current_user) { owner }

    subject(:resolve) { mutation.resolve(full_path: container.full_path, security_policy_project_id: policy_project_id) }

    shared_context 'assigns security policy project' do
      context 'when licensed feature is available' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        context 'when user is an owner of the container' do
          before do
            container.add_owner(owner)
          end

          context 'when user has at least reporter access on the security project' do
            before_all do
              policy_project.add_reporter(owner)
            end

            it 'assigns the security policy project' do
              result = subject

              expect(result[:errors]).to be_empty
              expect(container.security_orchestration_policy_configuration).not_to be_nil
              expect(container.security_orchestration_policy_configuration.security_policy_management_project).to eq(policy_project)
            end

            context 'when already assigned' do
              let!(:policy_configuration) do
                case container
                when Project
                  create(:security_orchestration_policy_configuration,
                    project_id: container.id,
                    security_policy_management_project: policy_project)
                when Group
                  create(:security_orchestration_policy_configuration,
                    :namespace,
                    namespace_id: container.id,
                    security_policy_management_project: policy_project)
                end
              end

              subject(:error) { resolve[:errors].first }

              it { is_expected.to match(/is already assigned/) }
            end
          end

          context 'when user is a not a member of the security project' do
            it 'raises exception' do
              expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
            end
          end
        end

        context 'when user is not an owner' do
          let(:current_user) { maintainer }

          before do
            container.add_maintainer(maintainer)
          end

          it 'raises exception' do
            expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end
      end

      context 'when policy_project_id is invalid' do
        let_it_be(:policy_project_id) { 'invalid' }

        it 'raises exception' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when feature is not licensed' do
        before do
          stub_licensed_features(security_orchestration_policies: false)
        end

        it 'raises exception' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when both fullPath and projectPath are not provided' do
      subject { mutation.resolve(security_policy_project_id: policy_project_id) }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'raises exception' do
        expect { subject }.to raise_error(Gitlab::Graphql::Errors::ArgumentError)
      end
    end

    context 'for project' do
      let(:container) { project }

      it_behaves_like 'assigns security policy project'
    end

    context 'for namespace' do
      let(:container) { namespace }

      it_behaves_like 'assigns security policy project'
    end
  end
end
