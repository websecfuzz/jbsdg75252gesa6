# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnAssignedUsersFinder, feature_category: :seat_cost_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group, owners: user) }
    let_it_be(:subgroup) { create(:group, parent: namespace) }
    let_it_be(:another_subgroup) { create(:group, parent: namespace) }
    let_it_be(:project) { create(:project, group: another_subgroup) }
    let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_pro) }

    subject(:assigned_users) { described_class.new(user, namespace, add_on_name: :code_suggestions).execute }

    describe '#execute' do
      context 'without add_on_purchase' do
        it { is_expected.to be_empty }
      end

      context 'with expired add_on_purchase' do
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :expired, add_on: add_on, namespace: namespace)
        end

        let_it_be(:member_with_duo_pro) do
          create(:user, developer_of: namespace).tap do |u|
            create(:gitlab_subscription_user_add_on_assignment, user: u, add_on_purchase: add_on_purchase)
          end
        end

        it { is_expected.to be_empty }
      end

      context 'with add on purchase available' do
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :active, add_on: add_on, namespace: namespace)
        end

        let_it_be(:member_with_duo_pro) do
          create(:user, developer_of: namespace).tap do |u|
            create(:gitlab_subscription_user_add_on_assignment, user: u, add_on_purchase: add_on_purchase)
          end
        end

        let_it_be(:subgroup_member_with_duo_pro) do
          create(:user, developer_of: subgroup).tap do |u|
            create(:gitlab_subscription_user_add_on_assignment, user: u, add_on_purchase: add_on_purchase)
          end
        end

        let_it_be(:another_subgroup_member_with_duo_pro) do
          create(:user, developer_of: another_subgroup).tap do |u|
            create(:gitlab_subscription_user_add_on_assignment, user: u, add_on_purchase: add_on_purchase)
          end
        end

        let_it_be(:project_member_with_duo_pro) do
          create(:user, developer_of: project).tap do |u|
            create(:gitlab_subscription_user_add_on_assignment, user: u, add_on_purchase: add_on_purchase)
          end
        end

        let_it_be(:member_without_duo_pro) { create(:user, developer_of: namespace) }

        it 'returns all assigned users of a group' do
          expect(assigned_users).to match_array([member_with_duo_pro, another_subgroup_member_with_duo_pro,
            subgroup_member_with_duo_pro])
        end

        context 'with subgroup' do
          let(:assigned_users) { described_class.new(user, subgroup, add_on_name: :code_suggestions).execute }

          it 'returns all subgroup members with assigned seat' do
            expect(assigned_users).to match_array([member_with_duo_pro, subgroup_member_with_duo_pro])
          end
        end

        context 'with project namespace' do
          let(:assigned_users) do
            described_class.new(user, project.project_namespace, add_on_name: :code_suggestions).execute
          end

          it 'returns all project members with assigned seat' do
            expect(assigned_users)
              .to match_array([member_with_duo_pro, another_subgroup_member_with_duo_pro, project_member_with_duo_pro])
          end
        end

        context 'with instance level add_on_purchase' do
          let_it_be(:add_on_purchase) do
            create(:gitlab_subscription_add_on_purchase, :active, :self_managed, add_on: add_on)
          end

          it 'returns all assigned users of given group' do
            expect(assigned_users).to match_array([member_with_duo_pro, another_subgroup_member_with_duo_pro,
              subgroup_member_with_duo_pro])
          end
        end
      end
    end
  end
end
