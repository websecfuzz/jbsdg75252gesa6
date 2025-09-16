# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/_form.html.haml', feature_category: :user_management do
  let(:namespace) { build(:group) }
  let(:user) { build(:user, namespace: namespace) }

  before do
    assign(:user, user)
  end

  context 'for namespace plan' do
    context 'when gitlab_com_subscriptions SaaS feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      it 'renders licensed features' do
        render

        expect(rendered).to have_text('Licensed Features')
      end

      it 'has plan related fields', :saas do
        build(:gitlab_subscription, namespace: namespace)

        render

        expect(rendered).to have_testid('plan-dropdown')
      end
    end

    context 'when gitlab_com_subscriptions SaaS feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'does not render licensed features' do
        render

        expect(rendered).not_to have_text('Licensed Features')
      end
    end
  end

  describe 'user type radios' do
    context 'when :admin_custom_roles feature flag is enabled' do
      before do
        render
      end

      it 'renders user_type partial' do
        expect(rendered).to render_template('admin/users/_user_type')
      end

      it 'does not render access level radios' do
        expect(rendered).not_to have_selector '#access_levels'
      end
    end

    context 'when :admin_custom_roles feature flag is disabled' do
      before do
        stub_feature_flags(custom_admin_roles: false)
        render
      end

      it 'renders access level radios' do
        expect(rendered).to have_selector '#access_levels'
      end

      it 'does not render user_type partial' do
        expect(rendered).to render_template('admin/users/_user_type')
      end
    end
  end
end
