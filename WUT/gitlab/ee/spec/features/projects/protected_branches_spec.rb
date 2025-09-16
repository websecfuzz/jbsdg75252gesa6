# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Protected Branches', :js, feature_category: :source_code_management do
  include ProtectedBranchHelpers

  context 'when a guest has custom roles with `admin_protected_branch` assigned' do
    let_it_be(:user) { create(:user) }
    let_it_be(:admin) { create(:admin) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, group: group) }
    let_it_be(:role) { create(:member_role, :guest, :admin_protected_branch, namespace: group) }
    let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }

    let(:success_message) { s_('ProtectedBranch|Protected branch was successfully created') }

    before do
      stub_licensed_features(custom_roles: true)
      sign_in(user)
    end

    it_behaves_like 'setting project protected branches'
  end
end
