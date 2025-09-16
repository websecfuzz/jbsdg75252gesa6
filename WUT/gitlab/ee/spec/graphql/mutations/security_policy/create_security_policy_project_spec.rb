# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Mutations::SecurityPolicy::CreateSecurityPolicyProject, feature_category: :security_policy_management do
  include GraphqlHelpers
  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  describe '#resolve' do
    let_it_be(:owner) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: owner.namespace) }

    let(:current_user) { owner }

    subject { mutation.resolve(full_path: container.full_path) }

    shared_context 'creates security policy project' do
      context 'when licensed feature is available' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        context 'when user is an owner of the container' do
          let(:current_user) { owner }

          before do
            namespace.add_owner(owner)
          end

          it 'returns project' do
            result = subject

            expect(result[:errors]).to be_empty
            expect(result[:project]).to eq(Project.last)
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
      subject { mutation.resolve({}) }

      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      it 'raises exception' do
        expect { subject }.to raise_error(Gitlab::Graphql::Errors::ArgumentError)
      end
    end

    context 'for project' do
      let(:container) { project }

      it_behaves_like 'creates security policy project'
    end

    context 'for namespace' do
      let(:container) { namespace }

      it_behaves_like 'creates security policy project'
    end
  end
end
