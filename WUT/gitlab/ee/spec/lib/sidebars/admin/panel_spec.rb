# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Panel, :enable_admin_mode, feature_category: :navigation do
  let_it_be(:user) { build(:admin) }

  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

  before do
    stub_licensed_features(
      custom_roles: true,
      service_accounts: true,
      admin_audit_log: true,
      custom_file_templates: true,
      elastic_search: true,
      license_scanning: true,
      product_analytics: true
    )
    stub_application_setting(grafana_enabled: true)
  end

  subject { described_class.new(context) }

  it_behaves_like 'a panel with uniquely identifiable menu items'
  it_behaves_like 'a panel without placeholders'
  it_behaves_like 'a panel instantiable by the anonymous user'

  shared_examples 'hides duo settings menu' do
    it 'does not render duo settings menu' do
      expect(menus).not_to include(instance_of(::Sidebars::Admin::Menus::DuoSettingsMenu))
    end
  end

  shared_examples 'shows duo settings menu' do
    it 'renders duo settings menu' do
      expect(menus).to include(instance_of(::Sidebars::Admin::Menus::DuoSettingsMenu))
    end
  end

  describe '#configure_menus' do
    let(:menus) { subject.instance_variable_get(:@menus) }
    let(:license) { build(:license, plan: License::PREMIUM_PLAN) }

    before do
      allow(License).to receive(:current).and_return(license)
    end

    context 'when instance is self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      context 'when instance has a paid license' do
        it_behaves_like 'shows duo settings menu'
      end

      context 'when instance has no paid license' do
        let(:license) { nil }

        it_behaves_like 'hides duo settings menu'
      end
    end

    context 'when instance is SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when instance has a paid license' do
        it_behaves_like 'shows duo settings menu'
      end

      context 'when instance has no paid license' do
        let(:license) { nil }

        it_behaves_like 'hides duo settings menu'
      end
    end
  end
end
