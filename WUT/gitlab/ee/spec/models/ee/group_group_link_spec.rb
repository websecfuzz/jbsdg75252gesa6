# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupGroupLink, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:group_group_link) { create(:group_group_link, shared_group: group, shared_with_group: create(:group)) }

  describe 'scopes' do
    describe '.in_shared_group' do
      it 'provides correct link records' do
        create(:group_group_link)

        expect(described_class.in_shared_group(group)).to match_array([group_group_link])
      end
    end

    describe '.not_in_shared_with_group' do
      it 'provides correct link records' do
        not_shared_with_group = create(:group)
        create(:group_group_link, shared_with_group: not_shared_with_group)

        expect(described_class.not_in_shared_with_group(not_shared_with_group)).to match_array([group_group_link])
      end
    end
  end

  describe 'validations' do
    describe '#group_with_allowed_email_domains' do
      shared_examples 'restricted membership by email domain' do
        subject do
          build(:group_group_link, shared_group: shared_group, shared_with_group: shared_with_group)
        end

        context 'shared group has membership restricted by allowed email domains' do
          before do
            create(:allowed_email_domain, group: shared_group.root_ancestor, domain: 'gitlab.com')
            create(:allowed_email_domain, group: shared_group.root_ancestor, domain: 'gitlab.cn')
          end

          context 'shared with group with a subset of allowed email domains' do
            before do
              create(:allowed_email_domain, group: shared_with_group.root_ancestor, domain: 'gitlab.com')
            end

            it { is_expected.to be_valid }
          end

          context 'shared with group containing domains outside the shared group allowed email domains' do
            before do
              create(:allowed_email_domain, group: shared_with_group.root_ancestor, domain: 'example.com')
            end

            it { is_expected.to be_invalid }
          end

          context 'shared with group does not have membership restricted by allowed domains' do
            it { is_expected.to be_invalid }
          end
        end

        context 'shared group does not have membership restricted by allowed domains' do
          context 'shared with group has membership restricted by allowed email domains' do
            before do
              create(:allowed_email_domain, group: shared_with_group.root_ancestor, domain: 'example.com')
            end

            it { is_expected.to be_valid }
          end

          context 'shared with group does not have membership restricted by allowed domains' do
            it { is_expected.to be_valid }
          end
        end
      end

      context 'shared group is the root ancestor' do
        let_it_be(:shared_group) { create(:group) }
        let_it_be(:shared_with_group) { create(:group) }

        it_behaves_like 'restricted membership by email domain'
      end

      context 'shared group is a subgroup' do
        let_it_be(:shared_group) { create(:group, parent: create(:group)) }
        let_it_be(:shared_with_group) { create(:group) }

        it_behaves_like 'restricted membership by email domain'
      end

      context 'shared with group is a subgroup' do
        let_it_be(:shared_group) { create(:group) }
        let_it_be(:shared_with_group) { create(:group, parent: create(:group)) }

        it_behaves_like 'restricted membership by email domain'
      end

      context 'shared and shared with group are subgroups' do
        let_it_be(:shared_group) { create(:group, parent: create(:group)) }
        let_it_be(:shared_with_group) { create(:group, parent: create(:group)) }

        it_behaves_like 'restricted membership by email domain'
      end
    end
  end

  describe '#human_access' do
    context 'when a member role is assigned to the group link' do
      let_it_be(:member_role) { create(:member_role, :instance) }
      let_it_be(:group_group_link) { create(:group_group_link, member_role_id: member_role.id) }

      before do
        allow(group_group_link).to receive(:custom_role_for_group_link_enabled?)
          .and_return(custom_role_for_group_link_enabled)
      end

      context 'when `custom_role_for_group_link_enabled` is false' do
        let(:custom_role_for_group_link_enabled) { false }

        it 'returns access level name' do
          expect(group_group_link.human_access).to eq('Developer')
        end
      end

      context 'when `custom_role_for_group_link_enabled` is true' do
        let(:custom_role_for_group_link_enabled) { true }

        it 'returns member role name' do
          expect(group_group_link.human_access).to eq(member_role.name)
        end
      end
    end
  end
end
