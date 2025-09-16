# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::Auth::Ldap::Group do
  include LdapHelpers

  before do
    stub_ldap_config(active_directory: true)
  end

  describe '#member_dns' do
    let(:adapter) { ldap_adapter }

    it 'resolves the correct member_dns when member has a range' do
      group_entry_page1 = ldap_group_entry_with_member_range(
        [user_dn('user1'), user_dn('user2'), user_dn('user3')],
        range_start: '0',
        range_end: '2'
      )
      group_entry_page2 = ldap_group_entry_with_member_range(
        [user_dn('user4'), user_dn('user5'), user_dn('user6')],
        range_start: '3',
        range_end: '*'
      )
      group = described_class.new(group_entry_page1, adapter)
      stub_ldap_adapter_group_members_in_range(group_entry_page2, adapter, range_start: '3')
      stub_ldap_adapter_nested_groups(group.dn, [], adapter)

      expect(group.member_dns).to match_array(
        %w[
          uid=user1,ou=users,dc=example,dc=com
          uid=user2,ou=users,dc=example,dc=com
          uid=user3,ou=users,dc=example,dc=com
          uid=user4,ou=users,dc=example,dc=com
          uid=user5,ou=users,dc=example,dc=com
          uid=user6,ou=users,dc=example,dc=com
        ]
      )
    end

    context 'when there are nested groups' do
      let(:group1_entry) do
        ldap_group_entry(
          [user_dn('user1'), user_dn('user2')],
          objectclass: 'group',
          member_attr: 'member'
        )
      end

      let(:group2_entry) do
        ldap_group_entry(
          [user_dn('user3'), user_dn('user4')],
          cn: 'ldap_group2',
          objectclass: 'group',
          member_attr: 'member',
          member_of: group1_entry.dn
        )
      end

      let(:group) { described_class.new(group1_entry, adapter) }

      it 'resolves the correct member_dns when there are nested groups' do
        group3_entry = ldap_group_entry(
          [user_dn('user5'), user_dn('user6')],
          cn: 'ldap_group3',
          objectclass: 'group',
          member_attr: 'member',
          member_of: group1_entry.dn
        )
        nested_groups = [group2_entry, group3_entry]
        stub_ldap_adapter_nested_groups(group.dn, nested_groups, adapter)
        stub_ldap_adapter_nested_groups(group2_entry.dn, [], adapter)
        stub_ldap_adapter_nested_groups(group3_entry.dn, [], adapter)

        expect(group.member_dns).to match_array(
          %w[
            uid=user1,ou=users,dc=example,dc=com
            uid=user2,ou=users,dc=example,dc=com
            uid=user3,ou=users,dc=example,dc=com
            uid=user4,ou=users,dc=example,dc=com
            uid=user5,ou=users,dc=example,dc=com
            uid=user6,ou=users,dc=example,dc=com
          ]
        )
      end

      it 'skips duplicate nested groups' do
        group3_entry = ldap_group_entry(
          [user_dn('user5'), user_dn('user6')],
          cn: 'ldap_group3',
          objectclass: 'group',
          member_attr: 'member',
          member_of: [group1_entry.dn, group2_entry.dn]
        )
        nested_groups = [group2_entry, group3_entry]
        stub_ldap_adapter_nested_groups(group.dn, nested_groups, adapter)
        stub_ldap_adapter_nested_groups(group2_entry.dn, [group3_entry], adapter)
        stub_ldap_adapter_nested_groups(group3_entry.dn, [], adapter)

        expect(adapter).to receive(:nested_groups).with(group3_entry.dn).once

        group.member_dns
      end

      it 'does not include group dns or users outside of the base' do
        # Spaces in the 3rd DN below are intentional to ensure we're sanitizing
        # DNs before comparing and not just doing a string compare.
        group3_entry = ldap_group_entry(
          [
            'cn=ldap_group2,ou=groups,dc=example,dc=com',
            'uid=foo,ou=users,dc=other,dc=com',
            'uid=bar,ou=users,dc=example , dc=com'
          ],
          cn: 'ldap_group3',
          objectclass: 'group',
          member_attr: 'member',
          member_of: group1_entry.dn
        )
        nested_groups = [group2_entry, group3_entry]
        stub_ldap_adapter_nested_groups(group.dn, nested_groups, adapter)
        stub_ldap_adapter_nested_groups(group2_entry.dn, [], adapter)
        stub_ldap_adapter_nested_groups(group3_entry.dn, [], adapter)

        expect(group.member_dns).not_to include('cn=ldap_group1,ou=groups,dc=example,dc=com')
        expect(group.member_dns).not_to include('uid=foo,ou=users,dc=other,dc=com')
        expect(group.member_dns).to include('uid=bar,ou=users,dc=example,dc=com')
      end

      it 'logs an error when the LDAP base is invalid' do
        stub_ldap_config(
          active_directory: true,
          base: 'invalid,dc=example,dc=com'
        )
        nested_groups = [group2_entry]
        stub_ldap_adapter_nested_groups(group.dn, nested_groups, adapter)
        stub_ldap_adapter_nested_groups(group2_entry.dn, [], adapter)

        expect(Gitlab::AppLogger)
          .to receive(:error).with(/Configured LDAP `base` is invalid: 'invalid,dc=example,dc=com'/)
        # Users in the top-level group always get added - they're not filtered
        # through the nested groups shenanigans.
        expect(group.member_dns).to match_array(
          %w[
            uid=user1,ou=users,dc=example,dc=com
            uid=user2,ou=users,dc=example,dc=com
          ]
        )
      end

      it 'logs a warning when an invalid member DN is found in an LDAP group' do
        group3_entry = ldap_group_entry(
          ['invalid,ou=user,ou=groups,dc=example,dc=com'],
          cn: 'ldap_group3',
          objectclass: 'group',
          member_attr: 'member',
          member_of: group1_entry.dn
        )
        nested_groups = [group2_entry, group3_entry]
        stub_ldap_adapter_nested_groups(group.dn, nested_groups, adapter)
        stub_ldap_adapter_nested_groups(group2_entry.dn, [], adapter)
        stub_ldap_adapter_nested_groups(group3_entry.dn, [], adapter)

        expect(Gitlab::AppLogger)
          .to receive(:info).with(/Returning original DN/)
        expect(Gitlab::AppLogger)
          .to receive(:warn).with(/Received invalid member/)
        expect(group.member_dns).not_to include('invalid,ou=user,ou=groups,dc=example,dc=com')
      end

      it 'resolves the correct member_dns when the LDAP base is not normalized' do
        # E.g. When `base` has uppercase characters and extraneous spaces.
        # Stub looks different because `LDAP#Config#base` must be exercised.
        stub_ldap_config(options: { 'base' => 'DC=example, DC= com' })

        nested_groups = [group2_entry]
        stub_ldap_adapter_nested_groups(group.dn, nested_groups, adapter)
        stub_ldap_adapter_nested_groups(group2_entry.dn, [], adapter)

        expect(group.member_dns).to match_array(
          %w[
            uid=user1,ou=users,dc=example,dc=com
            uid=user2,ou=users,dc=example,dc=com
            uid=user3,ou=users,dc=example,dc=com
            uid=user4,ou=users,dc=example,dc=com
          ]
        )
      end
    end

    it 'removes extraneous spaces from DNs' do
      group_entry_page1 = ldap_group_entry_with_member_range(
        [' uid =  user1   ,  ou = users,dc=example,dc=com'],
        range_start: '0',
        range_end: '0'
      )
      group_entry_page2 = ldap_group_entry_with_member_range(
        [' uid =user2,  ou = users, dc  = example, dc=com  '],
        range_start: '1',
        range_end: '*'
      )
      group = described_class.new(group_entry_page1, adapter)
      stub_ldap_adapter_group_members_in_range(group_entry_page2, adapter, range_start: '1')
      stub_ldap_adapter_nested_groups(group.dn, [], adapter)

      expect(group.member_dns).to match_array(
        %w[
          uid=user1,ou=users,dc=example,dc=com
          uid=user2,ou=users,dc=example,dc=com
        ]
      )
    end
  end
end
