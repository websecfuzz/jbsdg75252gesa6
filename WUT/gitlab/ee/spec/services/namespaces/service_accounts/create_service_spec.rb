# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::CreateService, feature_category: :user_management do
  shared_examples 'service account creation failure' do
    it 'produces an error', :aggregate_failures do
      expect(result.status).to eq(:error)
      expect(result.message).to eq(
        s_('ServiceAccount|User does not have permission to create a service account in this namespace.')
      )
    end
  end

  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, :private, parent: group) }

  let(:namespace_id) { group.id }

  subject(:service) do
    described_class.new(current_user, { organization_id: organization.id, namespace_id: namespace_id })
  end

  context 'when self-managed' do
    before do
      stub_licensed_features(service_accounts: true)
      allow(License).to receive(:current).and_return(license)
    end

    context 'when current user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      context 'when subscription is of starter plan' do
        let(:license) { create(:license, plan: License::STARTER_PLAN) }

        it 'raises error' do
          expect(result.status).to eq(:error)
          expect(result.message).to include('No more seats are available to create Service Account User')
        end
      end

      context 'when subscription is ultimate tier' do
        let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

        it_behaves_like 'service account creation success' do
          let(:username_prefix) { "service_account_group_#{group.id}" }
        end

        it 'sets provisioned by group' do
          expect(result.payload[:user].provisioned_by_group_id).to eq(group.id)
        end

        context 'when the group is invalid' do
          let(:namespace_id) { non_existing_record_id }

          it_behaves_like 'service account creation failure'
        end

        context 'when the group is subgroup' do
          let(:namespace_id) { subgroup.id }

          it_behaves_like 'service account creation failure'
        end
      end

      context 'when subscription is of premium tier' do
        let(:license) { create(:license, plan: License::PREMIUM_PLAN) }
        let_it_be(:service_account1) { create(:user, :service_account, provisioned_by_group_id: group.id) }
        let_it_be(:service_account2) { create(:user, :service_account, provisioned_by_group_id: group.id) }

        context 'when premium seats are not available' do
          before do
            allow(license).to receive(:seats).and_return(1)
          end

          it 'raises error' do
            expect(result.status).to eq(:error)
            expect(result.message).to include('No more seats are available to create Service Account User')
          end
        end

        context 'when premium seats are available' do
          before do
            allow(license).to receive(:seats).and_return(User.service_account.count + 2)
          end

          it_behaves_like 'service account creation success' do
            let(:username_prefix) { "service_account_group_#{group.id}" }
          end

          it 'sets provisioned by group' do
            expect(result.payload[:user].provisioned_by_group_id).to eq(group.id)
          end

          context 'when the group is invalid' do
            let(:namespace_id) { non_existing_record_id }

            it_behaves_like 'service account creation failure'
          end

          context 'when the group is subgroup' do
            let(:namespace_id) { subgroup.id }

            it_behaves_like 'service account creation failure'
          end
        end
      end
    end

    context 'when current user is not an admin' do
      let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }

      context "when not a group owner" do
        let_it_be(:current_user) { create(:user, maintainer_of: group) }

        it_behaves_like 'service account creation failure'
      end

      context 'when group owner' do
        let_it_be(:current_user) { create(:user, owner_of: group) }

        context 'when application setting is disabled' do
          before do
            stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: false)
          end

          it_behaves_like 'service account creation failure'

          context 'when saas', :saas do
            it_behaves_like 'service account creation failure'
          end
        end

        context 'when application setting is enabled' do
          before do
            stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
          end

          it_behaves_like 'service account creation success' do
            let(:username_prefix) { "service_account_group_#{group.id}" }
          end

          context 'when saas', :saas do
            it_behaves_like 'service account creation success' do
              let(:username_prefix) { "service_account_group_#{group.id}" }
            end
          end

          # setting is only applicable for top level group
          context 'when the group is subgroup' do
            let(:namespace_id) { subgroup.id }

            it_behaves_like 'service account creation failure'

            context 'when saas', :saas do
              it_behaves_like 'service account creation failure'
            end
          end
        end
      end
    end
  end

  def result
    service.execute
  end
end
