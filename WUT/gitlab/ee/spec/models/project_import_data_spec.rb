# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectImportData do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }

  let(:import_url) { 'ssh://example.com' }
  let(:import_data_attrs) { { auth_method: 'ssh_public_key' } }
  let(:project) { build(:project, :mirror, creator: user, import_url: import_url, import_data_attributes: import_data_attrs) }

  subject(:import_data) { project.import_data }

  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:auth_method).in_array(%w[password ssh_public_key]).allow_nil.allow_blank }
  end

  describe '#ssh_key_auth?' do
    where(:import_url, :auth_method, :expected) do
      'ssh://example.com'  | 'ssh_public_key' | true
      'ssh://example.com'  | 'password'       | false
      'http://example.com' | 'ssh_public_key' | false
      'http://example.com' | 'password'       | false
    end

    with_them do
      let(:import_data_attrs) { { auth_method: auth_method } }

      subject { import_data.ssh_key_auth? }

      it { is_expected.to eq(expected) }
    end
  end

  describe '#ssh_known_hosts_verified_by' do
    subject(:ssh_known_hosts_verified_by) { import_data.ssh_known_hosts_verified_by }

    it 'is a user when ssh_known_hosts_verified_by_id is a valid id' do
      import_data.ssh_known_hosts_verified_by_id = user.id

      is_expected.to eq(user)
    end

    it 'is nil when ssh_known_hosts_verified_by_id is an invalid id' do
      import_data.ssh_known_hosts_verified_by_id = -1

      is_expected.to be_nil
    end

    context 'when ssh_known_hosts_verified_by_id is nil' do
      it { is_expected.to be_nil }

      it 'does not try to fetch a user' do
        # warm-up
        project

        expect { ssh_known_hosts_verified_by }.not_to exceed_query_limit(0)
      end
    end
  end

  describe 'auth_method' do
    [nil, ''].each do |value|
      it "returns 'password' when #{value.inspect}" do
        import_data.auth_method = value

        expect(import_data.auth_method).to eq('password')
      end
    end
  end

  describe 'credential fields accessors' do
    %i[
      auth_method
      password
      ssh_known_hosts
      ssh_known_hosts_verified_at
      ssh_known_hosts_verified_by_id
      ssh_private_key
      user
    ].each do |field|
      context "#{field} accessor" do
        it 'sets the value in the credentials hash' do
          import_data.send("#{field}=", 'foo')

          expect(import_data.credentials[field]).to eq('foo')
        end

        it 'sets a not-present value to nil' do
          import_data.send("#{field}=", '')

          expect(import_data.credentials[field]).to be_nil
        end

        it 'returns the data in the credentials hash' do
          import_data.credentials[field] = 'foo'

          expect(import_data.send(field)).to eq('foo')
        end
      end
    end
  end

  describe '#ssh_mirror_url?' do
    where(:import_url, :expected) do
      'ssh://example.com'   | true
      'git://example.com'   | false
      'http://example.com'  | false
      'https://example.com' | false
      nil                   | nil
    end

    with_them do
      subject { import_data.ssh_mirror_url? }

      it { is_expected.to eq(expected) }
    end
  end

  describe '#ssh_known_hosts_fingerprints' do
    subject { import_data.ssh_known_hosts_fingerprints }

    it 'defers to SshHostKey#fingerprint_host_keys' do
      import_data.ssh_known_hosts = 'known_hosts'

      expect(SshHostKey).to receive(:fingerprint_host_keys).with('known_hosts').and_return(:result)

      is_expected.to eq(:result)
    end
  end

  describe '#ssh_public_key' do
    subject { import_data.ssh_public_key }

    context 'no SSH key' do
      it { is_expected.to be_nil }
    end

    context 'with SSH key' do
      before do
        # The key should be generated regardless of the URL, as long as the
        # auth method is correct
        project.import_url = nil

        # Triggers the `before_validation` callback
        import_data.valid?
      end

      it 'returns the public counterpart of the SSH private key' do
        comment = "git@#{::Gitlab.config.gitlab.host}"
        public_counterpart = SSHData::PrivateKey.parse(import_data.ssh_private_key).first.public_key.openssh(comment: comment)

        is_expected.to eq(public_counterpart)
      end
    end
  end

  describe '#regenerate_ssh_private_key' do
    %w[password ssh_public_key].each do |auth_method|
      context "auth_method is #{auth_method}" do
        let(:import_data_attrs) { { auth_method: auth_method } }

        it 'regenerates the SSH private key' do
          initial = import_data.ssh_private_key

          import_data.regenerate_ssh_private_key = true
          import_data.valid?

          expect(import_data.ssh_private_key).not_to eq(initial)
        end
      end
    end
  end
end
