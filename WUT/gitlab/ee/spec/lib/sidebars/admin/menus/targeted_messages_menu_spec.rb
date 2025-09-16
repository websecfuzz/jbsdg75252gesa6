# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::TargetedMessagesMenu, :saas, feature_category: :navigation do
  it_behaves_like 'Admin menu',
    link: '/admin/targeted_messages',
    title: s_('Admin|Targeted messages'),
    icon: 'messages'

  it_behaves_like 'Admin menu without sub menus', active_routes: { controller: :targeted_messages }

  describe '#render?', :enable_admin_mode do
    subject(:menu) { described_class.new(context) }

    let_it_be(:admin) { build(:admin) }
    let(:context) { Sidebars::Context.new(current_user: admin, container: nil) }

    it 'renders when all conditions are met' do
      expect(menu.render?).to be true
    end

    context 'when feature flag is off' do
      it 'does not render' do
        stub_feature_flags(targeted_messages_admin_ui: false)

        expect(menu.render?).to be false
      end
    end

    context 'when not on saas' do
      it 'does not render' do
        allow(Gitlab::Saas).to receive(:feature_available?).and_return(false)

        expect(menu.render?).to be false
      end
    end

    context 'when user is not admin' do
      let(:context) { Sidebars::Context.new(current_user: build(:user), container: nil) }

      it 'does not render' do
        expect(menu.render?).to be false
      end
    end
  end
end
