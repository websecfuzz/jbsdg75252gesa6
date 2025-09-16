# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::MonitoringMenu, feature_category: :navigation do
  subject(:menu) do
    described_class.new(Sidebars::Context.new(current_user: user, container: nil))
  end

  let_it_be(:user, refind: true) { create(:user) }

  describe '#render?' do
    context 'with a non-admin user', :enable_admin_mode do
      before do
        stub_licensed_features(admin_audit_log: true, custom_roles: true)
      end

      it { is_expected.not_to be_render }

      context 'with read_admin_monitoring ability' do
        let_it_be(:membership) { create(:admin_member_role, :read_admin_monitoring, user: user) }

        it { is_expected.to be_render }
      end
    end
  end

  describe "#renderable_items" do
    context "when user has `read_admin_monitoring`", :enable_admin_mode do
      subject(:menu_items) { menu.renderable_items.map(&:title) }

      let_it_be(:membership) { create(:admin_member_role, :read_admin_monitoring, user: user) }

      before do
        stub_licensed_features(admin_audit_log: true, custom_roles: true)
      end

      it 'includes the expected menu items' do
        is_expected.to contain_exactly(
          _('Audit events'),
          _('Background migrations'),
          _('Health check'),
          _('System information')
        )
      end
    end
  end
end
