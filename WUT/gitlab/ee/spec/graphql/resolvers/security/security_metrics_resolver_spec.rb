# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::SecurityMetricsResolver, feature_category: :vulnerability_management do
  include GraphqlHelpers

  subject(:resolved_metrics) do
    resolve(described_class, obj: operate_on, args: args, ctx: { current_user: current_user })
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:current_user) { create(:user) }

  describe '#resolve' do
    let(:args) { {} }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    specify do
      expect(described_class).to have_nullable_graphql_type(Types::Security::SecurityMetricsType)
    end

    shared_examples 'returns the object when authorized' do
      it 'returns the object' do
        expect(resolved_metrics).to eq(operate_on)
      end

      context 'with filter arguments' do
        let(:args) { filter_args }

        it 'returns the object with filters applied' do
          expect(resolved_metrics).to eq(operate_on)
        end
      end

      context 'with invalid arguments' do
        let(:args) { { project_id: ['invalid-gid'] } }

        it 'handles invalid arguments gracefully' do
          expect(resolved_metrics).to eq(operate_on)
        end
      end
    end

    shared_examples 'returns resource not available error when unauthorized' do
      it 'returns a resource not available error' do
        expect(resolved_metrics).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when operated on a group' do
      let(:operate_on) { group }
      let(:filter_args) do
        {
          project_id: [project.to_global_id.to_s],
          severity: ['critical'],
          scanner: ['sast']
        }
      end

      context 'when the current user has access' do
        before_all do
          group.add_maintainer(current_user)
        end

        it_behaves_like 'returns the object when authorized'
      end

      context 'when the current user does not have access' do
        it_behaves_like 'returns resource not available error when unauthorized'
      end
    end

    context 'when security_dashboard feature flag is disabled' do
      let(:operate_on) { group }

      before_all do
        group.add_maintainer(current_user)
      end

      before do
        stub_licensed_features(security_dashboard: false)
      end

      it_behaves_like 'returns resource not available error when unauthorized'
    end
  end
end
