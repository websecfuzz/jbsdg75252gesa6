# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Preloaders::GroupPolicyPreloader, feature_category: :shared do
  let_it_be(:user) { create(:user) }
  let_it_be(:root_parent) { create(:group, :private, name: 'root-1', path: 'root-1') }
  let_it_be(:guest_group) { create(:group, name: 'public guest', path: 'public-guest', guests: user) }
  let_it_be(:private_maintainer_group) { create(:group, :private, name: 'b private maintainer', path: 'b-private-maintainer', parent: root_parent, maintainers: user) }
  let_it_be(:private_developer_group) { create(:group, :private, project_creation_level: nil, name: 'c public developer', path: 'c-public-developer', developers: user) }
  let_it_be(:public_maintainer_group) { create(:group, :private, name: 'a public maintainer', path: 'a-public-maintainer', maintainers: user) }

  let_it_be(:member_role) { create(:member_role, :guest, :admin_group_member, :instance) }

  let(:base_groups) { [guest_group, private_maintainer_group, private_developer_group, public_maintainer_group] }

  context 'when ip_restrictions feature and custom roles feature is enabled' do
    before do
      stub_licensed_features(group_ip_restriction: true, custom_roles: true)
    end

    it 'avoids N+1 queries when authorizing a list of groups', :request_store do
      preload_groups_for_policy(user)
      control = ActiveRecord::QueryRecorder.new { authorize_all_groups(user) }

      new_group1 = create(:group, :private, maintainers: user)
      new_group2 = create(:group, :private, parent: private_maintainer_group)

      another_root = create(:group, :private, name: 'root-3', path: 'root-3')
      new_group3 = create(:group, :private, parent: another_root, maintainers: user)

      new_group4 = create(:group, :private)
      create(:group_member, :guest, user: user, group: new_group4, member_role: member_role)

      new_group5 = create(:group, :private)
      create(:group_member, :guest, user: user, group: new_group5, member_role: member_role)

      pristine_groups = Group.where(id: base_groups + [new_group1, new_group2, new_group3, new_group4, new_group5]).to_a

      preload_groups_for_policy(user, pristine_groups)
      expect { authorize_all_groups(user, pristine_groups) }.not_to exceed_query_limit(control)
    end
  end

  def authorize_all_groups(current_user, group_list = base_groups)
    group_list.each { |group| current_user.can?(:admin_group_member, group) }
  end

  def preload_groups_for_policy(current_user, group_list = base_groups)
    described_class.new(group_list, current_user).execute
  end
end
