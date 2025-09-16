# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupLinksHelper, feature_category: :system_access do
  let_it_be(:group) { create_default(:group) }
  let_it_be(:user) { create_default(:user, owner_of: group) }
  let_it_be(:member_role) { create_default(:member_role, namespace: group) }
  let_it_be(:group_link) { create_default(:saml_group_link, group: group, member_role: member_role) }

  describe '#group_link_role_selector_data', :saas, feature_category: :permissions do
    let(:expected_standard_role_data) { { standard_roles: group.access_level_roles } }
    let(:expected_custom_role_data) do
      { custom_roles: [{ member_role_id: member_role.id,
                         name: member_role.name,
                         base_access_level: member_role.base_access_level }] }
    end

    subject(:data) { helper.group_link_role_selector_data(group, user) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'returns a hash with the expected standard and custom role data' do
      expect(data).to eq(expected_standard_role_data.merge(expected_custom_role_data))
    end

    context 'when custom roles are not enabled' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'returns a hash with the expected standard role data' do
        expect(data).to eq(expected_standard_role_data)
      end
    end
  end

  describe '#group_link_role_name' do
    subject { helper.group_link_role_name(group_link) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when a member role is present' do
      it { is_expected.to eq(member_role.name) }
    end

    context 'when a member role is not present' do
      let_it_be(:group_link) { create_default(:saml_group_link, group: group, member_role: nil) }

      it { is_expected.to eq('Guest') }
    end

    context 'when custom roles are disabled' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it { is_expected.to eq('Guest') }
    end
  end

  describe '#custom_role_for_group_link_enabled?' do
    subject(:custom_role_enabled) { helper.custom_role_for_group_link_enabled?(group) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when on SaaS', :saas do
      context 'when feature-flag `assign_custom_roles_to_group_links_saas` for group is enabled' do
        before do
          stub_feature_flags(assign_custom_roles_to_group_links_saas: [group])
        end

        it { is_expected.to be(true) }

        context 'when subject is sub-group' do
          let(:sub_group) { build(:group, parent: group) }

          subject(:custom_role_enabled_for_subgroup) { helper.custom_role_for_group_link_enabled?(sub_group) }

          it { is_expected.to be(true) }
        end
      end

      context 'when feature-flag `assign_custom_roles_to_group_links_saas` for another group is enabled' do
        let(:another_group) { build(:group) }

        before do
          stub_feature_flags(assign_custom_roles_to_group_links_saas: [another_group])
        end

        it { is_expected.to be(false) }
      end

      context 'when feature-flag `assign_custom_roles_to_group_links_saas` is disabled' do
        before do
          stub_feature_flags(assign_custom_roles_to_group_links_saas: false)
        end

        it { is_expected.to be(false) }
      end

      context 'when custom roles are disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when on self-managed' do
      context 'when feature-flag `assign_custom_roles_to_group_links_sm` is enabled' do
        it { is_expected.to be(true) }
      end

      context 'when feature-flag `assign_custom_roles_to_group_links_sm` is disabled' do
        before do
          stub_feature_flags(assign_custom_roles_to_group_links_sm: false)
        end

        it { is_expected.to be(false) }
      end

      context 'when custom roles are disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { is_expected.to be(false) }
      end
    end
  end
end
