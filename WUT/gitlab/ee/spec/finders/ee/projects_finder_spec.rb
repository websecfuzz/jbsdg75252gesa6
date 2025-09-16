# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectsFinder, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax

  describe '#execute', :saas do
    let_it_be(:user) { create(:user) }
    let_it_be(:ultimate_project) { create_project(:ultimate_plan) }
    let_it_be(:ultimate_project2) { create_project(:ultimate_plan) }
    let_it_be(:premium_project) { create_project(:premium_plan) }
    let_it_be(:no_plan_project) { create_project(nil) }

    let(:current_user) { user }
    let(:project_ids_relation) { nil }
    let(:finder) { described_class.new(current_user:, params:, project_ids_relation:) }

    subject { finder.execute }

    describe 'filter by plans' do
      let(:params) { { plans: plans } }

      context 'with ultimate plan' do
        let(:plans) { ['ultimate'] }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2) }
      end

      context 'with multiple plans' do
        let(:plans) { %w[ultimate premium] }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project) }
      end

      context 'with other plans' do
        let(:plans) { ['bronze'] }

        it { is_expected.to be_empty }
      end

      context 'without plans' do
        let(:plans) { nil }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project) }
      end

      context 'with empty plans' do
        let(:plans) { [] }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project) }
      end
    end

    it_behaves_like 'projects finder with SAML session filtering' do
      let(:finder) { described_class.new(current_user: current_user, params: params) }
    end

    context 'filter by hidden' do
      let_it_be(:hidden_project) { create(:project, :public, :hidden) }

      context 'when include hidden is true' do
        let_it_be(:params) { { include_hidden: true } }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project, hidden_project) }
      end

      context 'when include hidden is false' do
        let_it_be(:params) { { include_hidden: false } }

        it { is_expected.to contain_exactly(ultimate_project, ultimate_project2, premium_project, no_plan_project) }
      end
    end

    context 'filter by feature available' do
      let_it_be(:private_premium_project) { create_project(:premium_plan, :private) }

      before do
        private_premium_project.add_owner(user)
      end

      context 'when feature_available filter is used' do
        # `product_analytics` is a feature available in Ultimate tier only
        let_it_be(:params) { { feature_available: 'product_analytics' } }

        it do
          is_expected.to contain_exactly(
            ultimate_project,
            ultimate_project2,
            premium_project,
            no_plan_project
          )
        end
      end

      context 'when feature_available filter is not used' do
        let_it_be(:params) { {} }

        it do
          is_expected.to contain_exactly(
            ultimate_project,
            ultimate_project2,
            premium_project,
            no_plan_project,
            private_premium_project
          )
        end
      end
    end

    private

    def create_project(plan, visibility = :public)
      create(:project, visibility, namespace: create(:group_with_plan, plan: plan))
    end
  end
end
