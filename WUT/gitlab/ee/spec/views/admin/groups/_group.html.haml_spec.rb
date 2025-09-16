# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/groups/_group', feature_category: :system_access do
  let(:group) { build(:group) }

  before do
    assign(:group, group)
    allow(group).to receive(:storage_size)
  end

  context 'for namespace plan badge' do
    context 'when gitlab_com_subscriptions SaaS feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when namespace is paid', :saas do
        before do
          build(:gitlab_subscription, :ultimate, namespace: group)
        end

        it 'renders the badge' do
          render 'admin/groups/group', group: group

          expect(rendered).to have_testid('plan-badge')
        end
      end

      context 'when namespace is not paid' do
        it 'does not render the badge' do
          render 'admin/groups/group', group: group

          expect(rendered).not_to have_testid('plan-badge')
        end
      end
    end

    context 'when gitlab_com_subscriptions SaaS feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when namespace is paid', :saas do
        before do
          build(:gitlab_subscription, :ultimate, namespace: group)
        end

        it 'does not render the badge' do
          render 'admin/groups/group', group: group

          expect(rendered).not_to have_testid('plan-badge')
        end
      end
    end
  end
end
