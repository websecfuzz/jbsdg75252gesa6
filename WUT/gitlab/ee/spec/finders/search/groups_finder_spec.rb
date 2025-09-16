# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupsFinder, feature_category: :global_search do
  describe '#execute' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group) }
    let(:params) { {} }

    subject(:execute) { described_class.new(user: user, params: params).execute }

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns nothing' do
        expect(execute).to be_empty
      end
    end

    context 'when user has no matching groups' do
      it 'returns nothing' do
        expect(execute).to be_empty
      end
    end

    context 'when features and min_access_level are both provided' do
      let(:params) { { features: [:foo], min_access_level: ::Gitlab::Access::GUEST } }

      it 'raises an exception' do
        expect { execute }.to raise_error(ArgumentError)
      end
    end

    context 'when user has direct membership with default role' do
      it 'returns that group' do
        group.add_developer(user)

        expect(execute).to contain_exactly(group)
      end

      context 'when features is provided' do
        context 'and user does not have access level required for feature' do
          let(:params) { { features: [:repository] } }

          it 'returns nothing' do
            group.add_guest(user)

            expect(execute).to be_empty
          end
        end

        context 'and user has access level required for feature' do
          let(:params) { { features: [:repository] } }

          it 'returns that group' do
            group.add_developer(user)

            expect(execute).to contain_exactly(group)
          end
        end
      end

      context 'when min_access_level higher than GUEST is provided' do
        let(:params) { { min_access_level: ::Gitlab::Access::OWNER } }

        it 'returns nothing' do
          group.add_guest(user)

          expect(execute).to be_empty
        end
      end
    end

    context 'when user has direct membership with custom role' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      let(:params) { { features: [:repository] } }

      context 'and user has custom role without the ability' do
        it 'returns nothing' do
          admin_runners_role = create(:member_role, :guest, :admin_runners, namespace: group, read_code: false)
          create(:group_member, :guest, member_role: admin_runners_role, user: user, source: group)

          expect(execute).to be_empty
        end
      end

      context 'and user has custom role with the ability' do
        it 'returns that group' do
          read_code_role = create(:member_role, :guest, :read_code, namespace: group)
          create(:group_member, :guest, member_role: read_code_role, user: user, source: group)

          expect(execute).to contain_exactly(group)
        end
      end
    end

    context 'when user has membership through a shared group link with default role' do
      let_it_be_with_reload(:shared_with_group) { create(:group) }
      let_it_be_with_reload(:group_group_link) do
        create(
          :group_group_link,
          group_access: ::Gitlab::Access::GUEST,
          shared_group: group,
          shared_with_group: shared_with_group
        )
      end

      it 'returns the direct access group and the shared group' do
        shared_with_group.add_developer(user)

        expect(execute).to contain_exactly(shared_with_group, group)
      end

      context 'and the group link is expired' do
        it 'returns only the direct access group' do
          shared_with_group.add_developer(user)
          group_group_link.update!(expires_at: 1.day.ago)

          expect(execute).to contain_exactly(shared_with_group)
        end
      end

      context 'and user does not have min_access_level required' do
        let(:params) { { min_access_level: ::Gitlab::Access::OWNER } }

        it 'returns nothing' do
          shared_with_group.add_guest(user)

          expect(execute).to be_empty
        end
      end

      context 'and user does not have access level required for feature' do
        let(:params) { { features: [:repository] } }

        it 'returns nothing' do
          shared_with_group.add_guest(user)

          expect(execute).to be_empty
        end
      end

      context 'and user has access level required for feature' do
        let(:params) { { features: [:repository] } }

        it 'returns the direct access group and the shared group' do
          group_group_link.update!(group_access: ::Gitlab::Access::DEVELOPER)
          shared_with_group.add_developer(user)

          expect(execute).to contain_exactly(shared_with_group, group)
        end
      end
    end

    context 'when user has membership through a shared group link with custom role' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      let_it_be_with_reload(:member_role) do
        create(:member_role, :guest, :admin_runners, namespace: group, read_code: false)
      end

      let_it_be_with_reload(:shared_with_group) { create(:group) }
      let_it_be_with_reload(:group_group_link) do
        create(:group_group_link, group_access: ::Gitlab::Access::GUEST,
          member_role: member_role, shared_with_group: shared_with_group, shared_group: group)
      end

      it 'returns the direct access group and the shared group' do
        shared_with_group.add_developer(user)

        expect(execute).to contain_exactly(shared_with_group, group)
      end

      context 'and the group link is expired' do
        it 'returns only the direct access group' do
          shared_with_group.add_developer(user)
          group_group_link.update!(expires_at: 1.day.ago)

          expect(execute).to contain_exactly(shared_with_group)
        end
      end

      context 'and user does not have access level required for feature' do
        let(:params) { { features: [:repository] } }

        it 'returns nothing' do
          member_role.update!(read_code: false)
          shared_with_group.add_guest(user)

          expect(execute).to be_empty
        end
      end

      context 'and user has access level required for feature' do
        let(:params) { { features: [:repository] } }

        it 'returns the direct access group and the shared group' do
          member_role.update!(read_code: true)
          shared_with_group.add_developer(user)

          expect(execute).to contain_exactly(shared_with_group)
        end
      end
    end
  end
end
