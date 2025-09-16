# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe EE::Gitlab::Auth::Ldap::AccessLevels do
  describe '#set' do
    let(:access_levels) { described_class.new }
    let(:dns) do
      %w[
        uid=johndoe,ou=users,dc=example,dc=com
        uid=janedoe,ou=users,dc=example,dc=com
      ]
    end

    subject { access_levels }

    context 'when access_levels is empty' do
      before do
        access_levels.set(dns, to: { base_access_level: Gitlab::Access::DEVELOPER, member_role_id: nil })
      end

      it do
        is_expected
          .to eq({
            'uid=janedoe,ou=users,dc=example,dc=com' => { base_access_level: Gitlab::Access::DEVELOPER,
                                                          member_role_id: nil },
            'uid=johndoe,ou=users,dc=example,dc=com' => { base_access_level: Gitlab::Access::DEVELOPER,
                                                          member_role_id: nil }
          })
      end
    end

    context 'when access_hash has existing entries' do
      let(:developer_dns) do
        %w[
          uid=janedoe,ou=users,dc=example,dc=com
          uid=jamesdoe,ou=users,dc=example,dc=com
        ]
      end

      let(:master_dns) do
        %w[
          uid=johndoe,ou=users,dc=example,dc=com
          uid=janedoe,ou=users,dc=example,dc=com
        ]
      end

      before do
        access_levels.set(master_dns, to: { base_access_level: Gitlab::Access::MAINTAINER, member_role_id: nil })
        access_levels.set(developer_dns, to: { base_access_level: Gitlab::Access::DEVELOPER, member_role_id: nil })
      end

      it 'keeps the higher of all access values' do
        is_expected
          .to eq({
            'uid=janedoe,ou=users,dc=example,dc=com' => { base_access_level: Gitlab::Access::MAINTAINER,
                                                          member_role_id: nil },
            'uid=johndoe,ou=users,dc=example,dc=com' => { base_access_level: Gitlab::Access::MAINTAINER,
                                                          member_role_id: nil },
            'uid=jamesdoe,ou=users,dc=example,dc=com' => { base_access_level: Gitlab::Access::DEVELOPER,
                                                           member_role_id: nil }
          })
      end
    end
  end
end
