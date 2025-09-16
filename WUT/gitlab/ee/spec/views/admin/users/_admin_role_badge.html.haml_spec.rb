# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/_admin_role_badge.html.haml', feature_category: :user_management do
  let_it_be(:user) { build(:user) }
  let_it_be(:role) { build(:member_role, :admin) }

  before do
    assign(:user, user)
  end

  context 'when the user is assigned an admin role' do
    it 'shows admin role badge' do
      allow(user).to receive(:member_role).and_return(role)
      render

      expect(rendered).to have_css('.badge-info', text: role.name)
      expect(rendered).to have_testid('admin-icon')
    end
  end

  context 'when the user is not assigned an admin role' do
    it 'does not show admin role badge' do
      allow(user).to receive(:member_role).and_return(nil)
      render

      expect(rendered).not_to have_css('.badge-info', text: role.name)
      expect(rendered).not_to have_testid('admin-icon')
    end
  end
end
