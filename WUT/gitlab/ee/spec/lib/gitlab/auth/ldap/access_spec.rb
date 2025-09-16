# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::Ldap::Access, feature_category: :system_access do
  include LdapHelpers

  let(:user) { create(:omniauth_user, :ldap) }
  let(:provider) { user.ldap_identity.provider }

  subject(:access) { described_class.new(user) }

  describe '#allowed?' do
    context 'LDAP user' do
      it 'finds a user by dn first' do
        allow(Gitlab::Auth::Ldap::Person).to receive(:disabled_via_active_directory?).and_return(false)
        expect(Gitlab::Auth::Ldap::Person).to receive(:find_by_dn).and_return(user)
        expect(Gitlab::Auth::Ldap::Person).not_to receive(:find_by_email)

        access.allowed?
      end

      it 'finds a user by email if not found by dn' do
        allow(Gitlab::Auth::Ldap::Person).to receive(:disabled_via_active_directory?).and_return(false)
        expect(Gitlab::Auth::Ldap::Person).to receive(:find_by_dn).and_return(nil)
        expect(Gitlab::Auth::Ldap::Person).to receive(:find_by_email).and_return(user)

        access.allowed?
      end

      it 'returns false if user cannot be found' do
        stub_ldap_person_find_by_dn(nil)
        stub_ldap_person_find_by_email(user.email, nil)

        expect(access.allowed?).to be_falsey
      end

      context 'when exists in LDAP/AD' do
        before do
          allow(Gitlab::Auth::Ldap::Person).to receive(:find_by_dn).and_return(user)
        end

        context 'user blocked in LDAP/AD' do
          before do
            allow(Gitlab::Auth::Ldap::Person).to receive(:disabled_via_active_directory?).and_return(true)
          end

          it 'blocks user in GitLab' do
            expect(access.allowed?).to be_falsey
            expect(user.blocked?).to be_truthy
            expect(user.ldap_blocked?).to be_truthy
          end

          context 'on a read-only instance' do
            before do
              allow(Gitlab::Database).to receive(:read_only?).and_return(true)
            end

            it 'does not block user in GitLab' do
              expect(access.allowed?).to be_falsey
              expect(user.blocked?).to be_falsey
              expect(user.ldap_blocked?).to be_falsey
            end
          end
        end

        context 'user unblocked in LDAP/AD' do
          before do
            user.update_column(:state, :ldap_blocked)
            allow(Gitlab::Auth::Ldap::Person).to receive(:disabled_via_active_directory?).and_return(false)
          end

          it 'unblocks user in GitLab' do
            expect(access.allowed?).to be_truthy
            expect(user.blocked?).to be_falsey
            expect(user.ldap_blocked?).to be_falsey
          end

          context 'on a read-only instance' do
            before do
              allow(Gitlab::Database).to receive(:read_only?).and_return(true)
            end

            it 'does not unblock user in GitLab' do
              expect(access.allowed?).to be_truthy
              expect(user.blocked?).to be_truthy
              expect(user.ldap_blocked?).to be_truthy
            end
          end
        end
      end

      context 'when no longer exist in LDAP/AD' do
        before do
          stub_ldap_person_find_by_dn(nil)
          stub_ldap_person_find_by_email(user.email, nil)
        end

        it 'blocks user in GitLab' do
          expect(access.allowed?).to be_falsey
          expect(user.blocked?).to be_truthy
          expect(user.ldap_blocked?).to be_truthy
        end

        context 'on a read-only instance' do
          before do
            allow(Gitlab::Database).to receive(:read_only?).and_return(true)
          end

          it 'does not block user in GitLab' do
            expect(access.allowed?).to be_falsey
            expect(user.blocked?).to be_falsey
            expect(user.ldap_blocked?).to be_falsey
          end
        end
      end
    end
  end

  describe '#update_user' do
    let(:entry) { Net::LDAP::Entry.from_single_ldif_string("dn: cn=foo, dc=bar, dc=com") }

    context 'email address' do
      before do
        stub_ldap_person_find_by_dn(entry, provider)
      end

      it 'does not update email if email attribute is not set' do
        expect { access.update_user }.not_to change(user, :email)
      end

      it 'does not update the email if the user has the same email in GitLab and in LDAP' do
        entry['mail'] = [user.email]

        expect { access.update_user }.not_to change(user, :email)
      end

      it 'does not update the email if the user has the same email GitLab and in LDAP, but with upper case in LDAP' do
        entry['mail'] = [user.email.upcase]

        expect { access.update_user }.not_to change(user, :email)
      end

      context 'when mail is different' do
        before do
          entry['mail'] = ['new_email@example.com']
        end

        it 'does not update the email when in a read-only GitLab instance' do
          allow(Gitlab::Database).to receive(:read_only?).and_return(true)

          expect { access.update_user }.not_to change(user, :email)
        end

        it 'updates the email if the user email is different' do
          expect { access.update_user }.to change(user, :email)
        end

        it 'does not update the name if the user email is different' do
          expect { access.update_user }.not_to change(user, :name)
        end

        context 'when the email is synced' do
          before do
            user.create_user_synced_attributes_metadata(email_synced: true, provider: 'ldapmain')
          end

          it 'updates the email if the user email is different' do
            expect { access.update_user }.to change { user.reload.email }.to('new_email@example.com')
          end

          it 'does not update if the new email is in use' do
            create(:user, email: 'new_email@example.com')
            expect { access.update_user }.not_to change { user.reload.email }
          end
        end
      end
    end

    context 'name' do
      before do
        stub_ldap_person_find_by_dn(entry, provider)
      end

      context 'when sync_name config is true' do
        before do
          allow(Gitlab.config.ldap).to receive(:enabled).and_return(true)
          stub_ldap_config(sync_name: true)
        end

        it 'does not update name if name attribute is not set' do
          expect { access.update_user }.not_to change(user, :name)
        end

        it 'does not update the name if the user has the same name in GitLab and in LDAP' do
          entry['cn'] = [user.name]

          expect { access.update_user }.not_to change(user, :name)
        end

        context 'when cn is different' do
          before do
            entry['cn'] = ['New Name']
          end

          it 'does not update the name when in a read-only GitLab instance' do
            allow(Gitlab::Database).to receive(:read_only?).and_return(true)

            expect { access.update_user }.not_to change(user, :name)
          end

          it 'updates the name if the user name is different' do
            expect { access.update_user }.to change(user, :name)
          end

          it 'does not update the email if the user name is different' do
            expect { access.update_user }.not_to change(user, :email)
          end

          it 'updates the name if the user name is different and user cannot change name manually in GitLab' do
            stub_licensed_features(disable_name_update_for_users: true)
            stub_application_setting(updating_name_disabled_for_users: true)

            expect { access.update_user }.to change(user, :name)
          end
        end

        context 'when first and last name attributes passed' do
          before do
            entry['givenName'] = ['Jane']
            entry['sn'] = ['Doe']
          end

          it 'does not update the name when in a read-only GitLab instance' do
            allow(Gitlab::Database).to receive(:read_only?).and_return(true)

            expect { access.update_user }.not_to change(user, :name)
          end

          it 'updates the name if the user name is different' do
            expect { access.update_user }.to change(user, :name).to('Jane Doe')
          end

          it 'does not update the email if the user name is different' do
            expect { access.update_user }.not_to change(user, :email)
          end
        end
      end

      context 'when sync_name config is false' do
        before do
          allow(Gitlab.config.ldap).to receive(:enabled).and_return(true)
          stub_ldap_config(sync_name: false)
        end

        it 'does not update name if name attribute is not set' do
          expect { access.update_user }.not_to change(user, :name)
        end

        it 'does not update the name if the user has the same name in GitLab and in LDAP' do
          entry['cn'] = [user.name]

          expect { access.update_user }.not_to change(user, :name)
        end

        context 'when cn is different' do
          before do
            entry['cn'] = ['New Name']
          end

          it 'does not update the name when in a read-only GitLab instance' do
            allow(Gitlab::Database).to receive(:read_only?).and_return(true)

            expect { access.update_user }.not_to change(user, :name)
          end

          it 'does not update the name if the user name is different' do
            expect { access.update_user }.not_to change(user, :name)
          end

          it 'does not update the email if the user name is different' do
            expect { access.update_user }.not_to change(user, :email)
          end
        end

        context 'when first and last name attributes passed' do
          before do
            entry['givenName'] = ['Jane']
            entry['sn'] = ['Doe']
          end

          it 'does not update the name when in a read-only GitLab instance' do
            allow(Gitlab::Database).to receive(:read_only?).and_return(true)

            expect { access.update_user }.not_to change(user, :name)
          end

          it 'does not update the name if the user name is different' do
            expect { access.update_user }.not_to change(user, :name)
          end

          it 'does not update the email if the user name is different' do
            expect { access.update_user }.not_to change(user, :email)
          end
        end
      end
    end

    context 'group memberships' do
      context 'when there is `memberof` param' do
        before do
          entry['memberof'] = [
            'CN=Group1,CN=Users,DC=The dc,DC=com',
            'CN=Group2,CN=Builtin,DC=The dc,DC=com'
          ]

          stub_ldap_person_find_by_dn(entry, provider)
        end

        it 'triggers a sync for all groups found in `memberof` for new users' do
          group_link_1 = create(:ldap_group_link, cn: 'Group1', provider: provider)
          group_link_2 = create(:ldap_group_link, cn: 'Group2', provider: provider)
          group_ids = [group_link_1, group_link_2].map(&:group_id)

          expect(LdapGroupSyncWorker).to receive(:perform_async)
            .with(a_collection_containing_exactly(*group_ids), provider)

          access.update_user
        end

        it "doesn't trigger a sync when in a read-only GitLab instance" do
          allow(Gitlab::Database).to receive(:read_only?).and_return(true)
          create(:ldap_group_link, cn: 'Group1', provider: provider)
          create(:ldap_group_link, cn: 'Group2', provider: provider)

          expect(LdapGroupSyncWorker).not_to receive(:perform_async)

          access.update_user
        end

        it "doesn't trigger a sync when there are no links for the provider" do
          _another_provider = create(:ldap_group_link,
            cn: 'Group1',
            provider: 'not-this-ldap')

          expect(LdapGroupSyncWorker).not_to receive(:perform_async)

          access.update_user
        end

        it 'does not performs the membership update for existing users' do
          user.created_at = Time.current - 10.minutes
          user.last_credential_check_at = Time.current
          user.save!

          expect(LdapGroupLink).not_to receive(:where)
          expect(LdapGroupSyncWorker).not_to receive(:perform_async)

          access.update_user
        end
      end

      it "doesn't continue when there is no `memberOf` param" do
        stub_ldap_person_find_by_dn(entry, provider)

        expect(LdapGroupLink).not_to receive(:where)
        expect(LdapGroupSyncWorker).not_to receive(:perform_async)

        access.update_user
      end
    end

    context 'SSH keys' do
      let_it_be(:ssh_key) { Gitlab::SSHPublicKey.new(SSHData::PrivateKey::RSA.generate(3072).public_key.openssh).key_text }

      let(:ssh_key_attribute_name) { 'altSecurityIdentities' }
      let(:entry) { Net::LDAP::Entry.from_single_ldif_string("dn: cn=foo, dc=bar, dc=com\n#{ssh_key_attribute_name}: SSHKey:#{ssh_key}\n#{ssh_key_attribute_name}: KerberosKey:bogus") }

      before do
        stub_ldap_config(sync_ssh_keys: ssh_key_attribute_name, sync_ssh_keys?: true)
      end

      it 'adds a SSH key if it is in LDAP but not in gitlab' do
        stub_ldap_person_find_by_dn(entry, provider)

        expect { access.update_user }.to change(user.keys, :count).from(0).to(1)
      end

      it 'adds a SSH key and give it a proper name' do
        stub_ldap_person_find_by_dn(entry, provider)

        access.update_user

        expect(user.keys.last.title).to match(/LDAP/)
        expect(user.keys.last.title).to match(/#{ssh_key_attribute_name}/)
      end

      it 'does not add a SSH key if it is invalid' do
        entry = Net::LDAP::Entry.from_single_ldif_string("dn: cn=foo, dc=bar, dc=com\n#{ssh_key_attribute_name}: I am not a valid key")
        stub_ldap_person_find_by_dn(entry, provider)

        expect { access.update_user }.not_to change(user.keys, :count)
      end

      it 'does not add a SSH key when in a read-only GitLab instance' do
        allow(Gitlab::Database).to receive(:read_only?).and_return(true)
        stub_ldap_person_find_by_dn(entry, provider)

        expect { access.update_user }.not_to change(user.keys, :count)
      end

      context 'user has at least one LDAPKey' do
        before do
          user.keys.ldap.create! key: ssh_key, title: 'to be removed'
        end

        it 'removes a SSH key if it is no longer in LDAP' do
          entry = Net::LDAP::Entry.from_single_ldif_string("dn: cn=foo, dc=bar, dc=com\n#{ssh_key_attribute_name}:\n")
          stub_ldap_person_find_by_dn(entry, provider)

          expect { access.update_user }.to change(user.keys, :count).from(1).to(0)
        end

        it 'removes a SSH key if the ldap attribute was removed' do
          entry = Net::LDAP::Entry.from_single_ldif_string("dn: cn=foo, dc=bar, dc=com")
          stub_ldap_person_find_by_dn(entry, provider)

          expect { access.update_user }.to change(user.keys, :count).from(1).to(0)
        end
      end
    end

    context 'kerberos identity' do
      before do
        stub_ldap_config(active_directory: true)
        stub_kerberos_setting(enabled: true)
        stub_ldap_person_find_by_dn(entry, provider)
      end

      it 'adds a Kerberos identity if it is in Active Directory but not in GitLab' do
        allow_any_instance_of(EE::Gitlab::Auth::Ldap::Person).to receive_messages(kerberos_principal: 'mylogin@FOO.COM')

        expect { access.update_user }.to change(user.identities.where(provider: :kerberos), :count).from(0).to(1)
        expect(user.identities.where(provider: 'kerberos').last.extern_uid).to eq('mylogin@FOO.COM')
      end

      it 'updates existing Kerberos identity in GitLab if Active Directory has a different one' do
        allow_any_instance_of(EE::Gitlab::Auth::Ldap::Person).to receive_messages(kerberos_principal: 'otherlogin@BAR.COM')
        user.identities.build(provider: 'kerberos', extern_uid: 'mylogin@FOO.COM').save!

        expect { access.update_user }.not_to change(user.identities.where(provider: 'kerberos'), :count)
        expect(user.identities.where(provider: 'kerberos').last.extern_uid).to eq('otherlogin@BAR.COM')
      end

      it 'does not remove Kerberos identities from GitLab if they are none in the LDAP provider' do
        allow_any_instance_of(EE::Gitlab::Auth::Ldap::Person).to receive_messages(kerberos_principal: nil)
        user.identities.build(provider: 'kerberos', extern_uid: 'otherlogin@BAR.COM').save!

        expect { access.update_user }.not_to change(user.identities.where(provider: 'kerberos'), :count)
        expect(user.identities.where(provider: 'kerberos').last.extern_uid).to eq('otherlogin@BAR.COM')
      end

      it 'does not modify identities in GitLab if they are no kerberos principal in the LDAP provider' do
        allow_any_instance_of(EE::Gitlab::Auth::Ldap::Person).to receive_messages(kerberos_principal: nil)

        expect { access.update_user }.not_to change(user.identities, :count)
      end

      it 'does not add a Kerberos identity when in a read-only GitLab instance' do
        allow(Gitlab::Database).to receive(:read_only?).and_return(true)
        allow_any_instance_of(EE::Gitlab::Auth::Ldap::Person).to receive_messages(kerberos_principal: 'mylogin@FOO.COM')

        expect { access.update_user }.not_to change(user.identities.where(provider: :kerberos), :count)
      end
    end

    context 'LDAP entity' do
      context 'whent external UID changed in the entry' do
        before do
          stub_ldap_person_find_by_dn(ldap_user_entry('another uid'), provider)
        end

        it 'updates the external UID' do
          access.update_user

          expect(user.ldap_identity.reload.extern_uid)
            .to eq('uid=another uid,ou=users,dc=example,dc=com')
        end

        it 'does not update the external UID when in a read-only GitLab instance' do
          allow(Gitlab::Database).to receive(:read_only?).and_return(true)

          access.update_user

          expect(user.ldap_identity.reload.extern_uid).to eq('123456')
        end
      end
    end
  end
end
