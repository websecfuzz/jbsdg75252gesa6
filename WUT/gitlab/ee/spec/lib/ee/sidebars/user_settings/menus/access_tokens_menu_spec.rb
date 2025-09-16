# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::UserSettings::Menus::AccessTokensMenu, feature_category: :system_access do
  subject(:sidebar_item) { described_class.new(context) }

  let_it_be(:user) { build(:user) }

  context 'when personal access tokens are disabled for enterprise users' do
    let(:user) { build(:enterprise_user) }

    before do
      allow(user.enterprise_group).to receive(:disable_personal_access_tokens?).and_return(true)
    end

    context 'when user is logged in' do
      let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

      it 'does not render' do
        expect(sidebar_item.render?).to be false
      end
    end

    context 'when user is not logged in' do
      let(:context) { Sidebars::Context.new(current_user: nil, container: nil) }

      subject { described_class.new(context) }

      it 'does not render' do
        expect(sidebar_item.render?).to be false
      end
    end
  end
end
