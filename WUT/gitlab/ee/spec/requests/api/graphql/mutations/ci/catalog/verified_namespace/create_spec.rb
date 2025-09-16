# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'VerifiedNamespaceCreate', feature_category: :pipeline_composition do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:project) { create(:project, group: root_namespace) }
  let_it_be(:group_project_resource) { create(:ci_catalog_resource, :published, project: project) }
  let(:verification_level) { 'GITLAB_MAINTAINED' }
  let(:namespace_path) { root_namespace.full_path }

  let(:mutation) do
    graphql_mutation(
      :verified_namespace_create,
      namespace_path: namespace_path,
      verification_level: verification_level
    )
  end

  let(:mutation_response) { graphql_mutation_response(:verified_namespace_create) }

  describe '#resolve' do
    context 'when on gitlab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
      end

      context 'when unauthorized' do
        let_it_be(:current_user) { build(:user) }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when the verified namespace given does not exist' do
        it 'creates a verified namespace' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(group_project_resource.reload.verification_level).to eq('gitlab_maintained')
          expect(Ci::Catalog::VerifiedNamespace.all.count).to eq(1)
        end
      end

      context 'when the verified namespace exists' do
        it 'updates the verified namespace with the new verification level' do
          ::Ci::Catalog::VerifyNamespaceService.new(root_namespace, 'verified_creator_maintained').execute
          expect(Ci::Catalog::VerifiedNamespace.all.count).to eq(1)
          expect(group_project_resource.reload.verification_level).to eq('verified_creator_maintained')

          post_graphql_mutation(mutation, current_user: current_user)

          expect(Ci::Catalog::VerifiedNamespace.all.count).to eq(1)
          expect(Ci::Catalog::VerifiedNamespace.first.verification_level).to eq('gitlab_maintained')
          expect(group_project_resource.reload.verification_level).to eq('gitlab_maintained')
        end
      end

      context 'when given an invalid verification level' do
        let(:verification_level) { 'unknown' }

        it 'returns an error' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { Ci::Catalog::VerifiedNamespace.all.count }

          expect { mutation_response }.to raise_error(GraphqlHelpers::NoData)
          expect(group_project_resource.reload.verification_level).to eq('unverified')
        end
      end

      context 'when given an invalid namespace path' do
        let(:subgroup) { create(:group, parent: root_namespace) }
        let(:namespace_path) { subgroup.full_path }

        it 'returns an error' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { Ci::Catalog::VerifiedNamespace.all.count }

          expect(mutation_response['errors']).to eq(['Input the root namespace.'])
          expect(group_project_resource.reload.verification_level).to eq('unverified')
        end
      end

      context 'when given both an invalid verification level and namespace path' do
        let(:subgroup) { create(:group, parent: root_namespace) }
        let(:namespace_path) { subgroup.full_path }
        let(:verification_level) { 'unknown' }

        it 'returns multiple errors' do
          error_message = 'Variable $verifiedNamespaceCreateInput of type ' \
            'VerifiedNamespaceCreateInput! was provided invalid value for verificationLevel'

          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.not_to change { Ci::Catalog::VerifiedNamespace.all.count }

          expect do
            mutation_response
          end.to raise_error(GraphqlHelpers::NoData) { |error|
            expect(error.message).to include(error_message)
          }

          expect(group_project_resource.reload.verification_level).to eq('unverified')
        end
      end
    end

    context 'when on self-managed' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      context 'when using an invalid verification level' do
        let(:verification_level) { 'GITLAB_MAINTAINED' }

        it 'returns an error' do
          post_graphql_mutation(mutation, current_user: build(:user))

          expect(mutation_response['errors']).to eq(['Cannot use gitlab_maintained on a non-Gitlab.com instance.' \
            'Use `VERIFIED_CREATOR_SELF_MANAGED`.'])
        end
      end

      context 'when verification level is verified_creator_self_managed' do
        let(:verification_level) { 'VERIFIED_CREATOR_SELF_MANAGED' }

        context 'when unauthorized' do
          let_it_be(:current_user) { build(:user) }

          it_behaves_like 'a mutation that returns a top-level access error'
        end

        context 'when the verified namespace given does not exist' do
          it 'creates a verified namespace' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(group_project_resource.reload.verification_level).to eq('verified_creator_self_managed')
            expect(Ci::Catalog::VerifiedNamespace.all.count).to eq(1)
          end
        end

        context 'when the verified namespace given exists' do
          it 'updates the verified namespace' do
            ::Ci::Catalog::VerifyNamespaceService.new(root_namespace, 'verified_creator_self_managed').execute
            expect(Ci::Catalog::VerifiedNamespace.all.count).to eq(1)
            expect(group_project_resource.reload.verification_level).to eq('verified_creator_self_managed')

            post_graphql_mutation(mutation, current_user: current_user)

            expect(Ci::Catalog::VerifiedNamespace.all.count).to eq(1)
            expect(Ci::Catalog::VerifiedNamespace.first.verification_level).to eq('verified_creator_self_managed')
            expect(group_project_resource.reload.verification_level).to eq('verified_creator_self_managed')
          end
        end
      end
    end
  end
end
