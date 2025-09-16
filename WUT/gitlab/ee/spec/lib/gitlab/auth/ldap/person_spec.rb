# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::Ldap::Person, feature_category: :system_access do
  include LdapHelpers

  let(:entry) { ldap_user_entry('john.doe') }

  it 'includes the EE module' do
    expect(described_class).to include(EE::Gitlab::Auth::Ldap::Person)
  end

  describe '.ldap_attributes' do
    it 'appends EE-specific attributes' do
      stub_ldap_config(sync_ssh_keys: 'sshPublicKey')
      expect(described_class.ldap_attributes(ldap_adapter.config)).to include('sshPublicKey')
    end

    it 'appends first and last name attributes' do
      stub_ldap_config(options: { 'attributes' => { 'first_name' => 'name', 'last_name' => 'surname' } })

      expect(described_class.ldap_attributes(ldap_adapter.config)).to include('name')
      expect(described_class.ldap_attributes(ldap_adapter.config)).to include('surname')
    end
  end

  describe '.find_by_email' do
    let(:adapter) { ldap_adapter }

    it 'tries finding for each configured email attribute' do
      expect(adapter).to receive(:user).with('mail', 'jane@gitlab.com')
      expect(adapter).to receive(:user).with('email', 'jane@gitlab.com')
      expect(adapter).to receive(:user).with('userPrincipalName', 'jane@gitlab.com')

      described_class.find_by_email('jane@gitlab.com', adapter)
    end

    it 'returns nil when no user was found' do
      allow(adapter).to receive(:user)

      found_user = described_class.find_by_email('jane@gitlab.com', adapter)

      expect(found_user).to eq(nil)
    end
  end

  describe '.find_by_certificate_issuer_and_serial' do
    it 'searches by certificate assertion' do
      adapter = ldap_adapter
      serial = 'serial'
      issuer_dn = 'issuer_dn'

      expect(adapter).to receive(:user_by_certificate_assertion).with("{ serialNumber #{serial}, issuer \"#{issuer_dn}\" }")

      described_class.find_by_certificate_issuer_and_serial(issuer_dn, serial, adapter)
    end
  end

  describe '.find_by_ad_certificate_field' do
    let(:smartcard_ad_cert_field) { 'extensionAttribute1' }

    it 'searches by active directory certificate assertion' do
      stub_ldap_config(smartcard_ad_cert_field: smartcard_ad_cert_field)

      filter_term = 'X509:<I>issuer_dn<SR>2a'
      adapter = ldap_adapter
      expect(adapter).to receive(:user).with(smartcard_ad_cert_field, filter_term)

      described_class.find_by_ad_certificate_field(filter_term, adapter)
    end
  end

  describe '.find_by_kerberos_principal' do
    let(:adapter) { ldap_adapter }
    let(:username) { 'foo' }
    let(:ldap_server) { 'ad.example.com' }

    subject(:ldap_person) { described_class.find_by_kerberos_principal(principal, adapter) }

    before do
      stub_ldap_config(uid: 'sAMAccountName', base: 'ou=foo,dc=' + ldap_server.gsub('.', ',dc='))
    end

    context 'when simple LDAP linking is not configured' do
      let(:principal) { username + '@' + kerberos_realm }

      context 'LDAP server is not for kerberos realm' do
        let(:kerberos_realm) { 'kerberos.example.com' }

        it 'returns nil without searching' do
          expect(adapter).not_to receive(:user)

          is_expected.to be_nil
        end
      end

      context 'LDAP server is for kerberos realm' do
        let(:kerberos_realm) { ldap_server }

        it 'searches by configured uid attribute' do
          expect(adapter).to receive(:user).with('sAMAccountName', username).and_return(:fake_user)

          is_expected.to eq(:fake_user)
        end
      end
    end

    context 'when simple LDAP linking is enabled' do
      let(:allowed_realms) { ['kerberos.example.com', ldap_server] }

      before do
        stub_config(kerberos: { simple_ldap_linking_allowed_realms: allowed_realms })
      end

      context 'principal domain matches an allowed realm' do
        let(:principal) { "#{username}@#{allowed_realms[0]}" }

        it 'searches by configured uid attribute' do
          expect(adapter).to receive(:user).with('sAMAccountName', username).and_return(:fake_user)

          expect(ldap_person).to eq(:fake_user)
        end
      end

      context 'principal domain does not match an allowed realm' do
        let(:principal) { "#{username}@alternate.example.com" }

        it 'returns nil without searching' do
          expect(adapter).not_to receive(:user)

          is_expected.to be_nil
        end
      end
    end
  end

  describe '.ldap_attributes' do
    def stub_sync_ssh_keys(value)
      stub_ldap_config(
        options: {
          'uid' => nil,
          'attributes' => {
            'name' => 'cn',
            'email' => 'mail',
            'username' => %w[uid mail],
            'first_name' => 'name',
            'last_name' => 'surname'
          },
          'sync_ssh_keys' => value
        }
      )
    end

    let(:config) { Gitlab::Auth::Ldap::Config.new('ldapmain') }
    let(:ldap_attributes) { described_class.ldap_attributes(config) }
    let(:expected_attributes) { %w[dn cn uid mail memberof name surname] }

    it 'includes a real attribute name' do
      stub_sync_ssh_keys('my-ssh-attribute')

      expect(ldap_attributes).to match_array(expected_attributes + ['my-ssh-attribute'])
    end

    it 'excludes integers' do
      stub_sync_ssh_keys(0)

      expect(ldap_attributes).to match_array(expected_attributes)
    end

    it 'excludes false values' do
      stub_sync_ssh_keys(false)

      expect(ldap_attributes).to match_array(expected_attributes)
    end

    it 'excludes true values' do
      stub_sync_ssh_keys(true)

      expect(ldap_attributes).to match_array(expected_attributes)
    end
  end

  describe '#kerberos_principal' do
    let(:entry) do
      ldif = "dn: cn=foo, dc=bar, dc=com\nsAMAccountName: myName\n"
      Net::LDAP::Entry.from_single_ldif_string(ldif)
    end

    subject { described_class.new(entry, 'ldapmain') }

    before do
      stub_ldap_config(uid: 'sAMAccountName')
    end

    it 'returns the principal combining the configured UID and DC components of the distinguishedName' do
      expect(subject.kerberos_principal).to eq('myName@BAR.COM')
    end
  end

  describe '#ssh_keys' do
    let(:ssh_key) { 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrSQHff6a1rMqBdHFt+FwIbytMZ+hJKN3KLkTtOWtSvNIriGhnTdn4rs+tjD/w+z+revytyWnMDM9dS7J8vQi006B16+hc9Xf82crqRoPRDnBytgAFFQY1G/55ql2zdfsC5yvpDOFzuwIJq5dNGsojS82t6HNmmKPq130fzsenFnj5v1pl3OJvk513oduUyKiZBGTroWTn7H/eOPtu7s9MD7pAdEjqYKFLeaKmyidiLmLqQlCRj3Tl2U9oyFg4PYNc0bL5FZJ/Z6t0Ds3i/a2RanQiKxrvgu3GSnUKMx7WIX373baL4jeM7cprRGiOY/1NcS+1cAjfJ8oaxQF/1dYj' }
    let(:ssh_key_attribute_name) { 'altSecurityIdentities' }
    let(:entry) do
      Net::LDAP::Entry.from_single_ldif_string("dn: cn=foo, dc=bar, dc=com\n#{keys}")
    end

    subject { described_class.new(entry, 'ldapmain') }

    before do
      allow_next_instance_of(Gitlab::Auth::Ldap::Config) do |instance|
        allow(instance).to receive_messages(sync_ssh_keys: ssh_key_attribute_name)
      end
    end

    context 'when the SSH key is literal' do
      let(:keys) { "#{ssh_key_attribute_name}: #{ssh_key}" }

      it 'includes the SSH key' do
        expect(subject.ssh_keys).to include(ssh_key)
      end
    end

    context 'when the SSH key is prefixed' do
      let(:keys) { "#{ssh_key_attribute_name}: SSHKey:#{ssh_key}" }

      it 'includes the SSH key' do
        expect(subject.ssh_keys).to include(ssh_key)
      end
    end

    context 'when the SSH key is suffixed' do
      let(:keys) { "#{ssh_key_attribute_name}: #{ssh_key} (SSH key)" }

      it 'includes the SSH key' do
        expect(subject.ssh_keys).to include(ssh_key)
      end
    end

    context 'when the SSH key is followed by a newline' do
      let(:keys) { "#{ssh_key_attribute_name}: #{ssh_key}\n" }

      it 'includes the SSH key' do
        expect(subject.ssh_keys).to include(ssh_key)
      end
    end

    context 'when the key is not an SSH key' do
      let(:keys) { "#{ssh_key_attribute_name}: KerberosKey:bogus" }

      it 'is empty' do
        expect(subject.ssh_keys).to be_empty
      end
    end

    context 'when there are multiple keys' do
      let(:keys) { "#{ssh_key_attribute_name}: #{ssh_key}\n#{ssh_key_attribute_name}: KerberosKey:bogus\n#{ssh_key_attribute_name}: ssh-rsa keykeykey" }

      it 'includes both SSH keys' do
        expect(subject.ssh_keys).to include(ssh_key)
        expect(subject.ssh_keys).to include('ssh-rsa keykeykey')
        expect(subject.ssh_keys).not_to include('KerberosKey:bogus')
      end
    end
  end

  describe '#memberof' do
    it 'returns an empty array if the field was not present' do
      person = described_class.new(entry, 'ldapmain')

      expect(person.memberof).to eq([])
    end

    it 'returns the values of `memberof` if the field was present' do
      example_memberof = ['CN=Group Policy Creator Owners,CN=Users,DC=Vosmaer,DC=com',
        'CN=Domain Admins,CN=Users,DC=Vosmaer,DC=com',
        'CN=Enterprise Admins,CN=Users,DC=Vosmaer,DC=com',
        'CN=Schema Admins,CN=Users,DC=Vosmaer,DC=com',
        'CN=Administrators,CN=Builtin,DC=Vosmaer,DC=com']
      entry['memberof'] = example_memberof
      person = described_class.new(entry, 'ldapmain')

      expect(person.memberof).to eq(example_memberof)
    end
  end

  describe '#cn_from_memberof' do
    it 'gets the group cn from the memberof value' do
      person = described_class.new(entry, 'ldapmain')

      expect(person.cn_from_memberof('CN=Group Policy Creator Owners,CN=Users,DC=Vosmaer,DC=com'))
        .to eq('Group Policy Creator Owners')
    end

    it "doesn't break when there is no CN property" do
      person = described_class.new(entry, 'ldapmain')

      expect(person.cn_from_memberof('DC=Vosmaer,DC=com'))
        .to be_nil
    end

    it "supports dashes in the group cn" do
      person = described_class.new(entry, 'ldapmain')

      expect(person.cn_from_memberof('CN=Group-Policy-Creator-Owners,CN=Users,DC=Vosmaer,DC=com'))
        .to eq('Group-Policy-Creator-Owners')
    end
  end

  describe '#group_cns' do
    it 'returns only CNs from the memberof values' do
      example_memberof = ['CN=Group Policy Creator Owners,CN=Users,DC=Vosmaer,DC=com',
        'CN=Administrators,CN=Builtin,DC=Vosmaer,DC=com']
      entry['memberof'] = example_memberof
      person = described_class.new(entry, 'ldapmain')

      expect(person.group_cns).to eq(['Group Policy Creator Owners', 'Administrators'])
    end
  end
end
