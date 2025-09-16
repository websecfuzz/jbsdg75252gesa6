# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SyncService, feature_category: :system_access do
  let_it_be(:user) { create(:user) }

  describe '#execute' do
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:group1) { create(:group, parent: top_level_group) }
    let_it_be(:group2) { create(:group, parent: top_level_group) }
    let_it_be(:member_role) do
      create(:member_role, namespace: top_level_group, base_access_level: Gitlab::Access::DEVELOPER)
    end

    let_it_be(:group_links) do
      [
        create(:saml_group_link, group: top_level_group, access_level: Gitlab::Access::GUEST),
        create(:saml_group_link, group: group1, access_level: Gitlab::Access::REPORTER),
        create(:saml_group_link, group: group1, access_level: Gitlab::Access::DEVELOPER),
        create(:saml_group_link, group: group1, access_level: Gitlab::Access::DEVELOPER, member_role: member_role)
      ]
    end

    let_it_be(:manage_group_ids) { [top_level_group.id, group1.id, group2.id] }

    subject(:sync) do
      described_class.new(
        top_level_group, user,
        group_links: group_links, manage_group_ids: manage_group_ids
      ).execute
    end

    it 'adds two new group member records' do
      expect { sync }.to change { GroupMember.count }.by(2)
    end

    it 'adds the user to top_level_group as Guest' do
      sync

      expect(top_level_group.members.find_by(user_id: user.id).access_level)
        .to eq(::Gitlab::Access::GUEST)
    end

    it 'adds the user to group1 as Developer' do
      sync

      expect(group1.members.find_by(user_id: user.id).access_level)
        .to eq(::Gitlab::Access::DEVELOPER)
    end

    it 'returns a success response' do
      expect(sync.success?).to eq(true)
    end

    it 'returns sync stats as payload' do
      expect(sync.payload).to include({ added: 2, removed: 0, updated: 0 })
    end

    context 'when a subgroup has no group links' do
      let_it_be(:subgroup) { create(:group, parent: group2, maintainers: user) }

      context 'when the user is a member to be removed from a parent group' do
        before_all do
          group2.add_developer(user)
        end

        it 'does not affect the subgroup member' do
          sync

          expect(subgroup.members.reload.find_by(user_id: user.id).access_level)
            .to eq(::Gitlab::Access::MAINTAINER)
        end
      end
    end

    describe 'custom roles', feature_category: :permissions do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'when custom roles are enabled' do
        it 'adds the user to group1 with a custom role' do
          expect(sync.payload).to include({ added: 2, removed: 0, updated: 0 })

          member = group1.member(user)

          expect(member.access_level).to eq(::Gitlab::Access::DEVELOPER)
          expect(member.member_role).to eq(member_role)
        end
      end

      context 'when custom roles are not enabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'adds the user to group1 without a custom role' do
          expect(sync.payload).to include({ added: 2, removed: 0, updated: 0 })

          member = group1.member(user)

          expect(member.access_level).to eq(::Gitlab::Access::DEVELOPER)
          expect(member.member_role).to eq(nil)
        end
      end
    end

    context 'when the user is already a member' do
      context 'with the correct access level' do
        before do
          group1.add_member(user, ::Gitlab::Access::DEVELOPER)
        end

        it 'does not change group member count' do
          expect { sync }.not_to change { group1.members.count }
        end

        it 'retains the correct access level' do
          sync

          expect(group1.members.find_by(user_id: user.id).access_level)
            .to eq(::Gitlab::Access::DEVELOPER)
        end

        it 'does not call Group find_by_id' do
          expect(Group).not_to receive(:find_by_id).with(group1.id)

          sync
        end
      end

      context 'with a different access level' do
        context 'when the user is not the last owner' do
          before do
            top_level_group.add_member(user, ::Gitlab::Access::MAINTAINER)
          end

          it 'does not change the group member count' do
            expect { sync }.not_to change { top_level_group.members.count }
          end

          it 'updates the access_level' do
            sync

            expect(top_level_group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::GUEST)
          end

          it 'returns sync stats as payload' do
            expect(sync.payload).to include({ added: 1, removed: 0, updated: 1 })
          end

          context 'when member promotion management is enabled' do
            let(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
            let!(:member_approval) do
              create(:gitlab_subscription_member_management_member_approval, :to_maintainer, user: user)
            end

            before do
              stub_application_setting(enable_member_promotion_management: true)
              allow(License).to receive(:current).and_return(license)
              allow(::Gitlab::EventStore).to receive(:publish).and_call_original
            end

            shared_examples 'does not publish MembershipModifiedByAdminEvent' do
              it 'does not publish MembershipModifiedByAdminEvent' do
                expect(::Gitlab::EventStore).not_to receive(:publish).with(
                  an_instance_of(::Members::MembershipModifiedByAdminEvent).and(
                    having_attributes(data: { member_user_id: user.id })
                  )
                )

                sync
              end
            end

            shared_examples 'publishes MembershipModifiedByAdminEvent' do
              it 'publishes MembershipModifiedByAdminEvent' do
                expect(::Gitlab::EventStore).to receive(:publish).with(
                  an_instance_of(::Members::MembershipModifiedByAdminEvent).and(
                    having_attributes(data: { member_user_id: user.id })
                  )
                )

                sync
              end
            end

            context 'when sync updates user on a non-billable access level' do
              let_it_be(:manage_group_ids) { [top_level_group.id] }

              let_it_be(:group_links) do
                [create(:saml_group_link, group: top_level_group, access_level: Gitlab::Access::GUEST)]
              end

              it_behaves_like 'does not publish MembershipModifiedByAdminEvent'
            end

            context 'when sync updates user on a billable access level' do
              let_it_be(:manage_group_ids) { [top_level_group.id, group1.id] }

              let_it_be(:group_links) do
                [create(:saml_group_link, group: group1, access_level: Gitlab::Access::DEVELOPER)]
              end

              before do
                group1.add_member(user, ::Gitlab::Access::GUEST)
              end

              context 'when there are pending promotions' do
                it_behaves_like 'publishes MembershipModifiedByAdminEvent'
              end

              context 'when there are no pending promotions' do
                let!(:member_approval) { nil }

                it_behaves_like 'does not publish MembershipModifiedByAdminEvent'
              end
            end
          end
        end

        context 'when the user is the last owner' do
          before do
            top_level_group.add_member(user, ::Gitlab::Access::OWNER)
          end

          it 'does not change the group member count' do
            expect { sync }.not_to change { top_level_group.members.count }
          end

          it 'does not update the access_level' do
            sync

            expect(top_level_group.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::OWNER)
          end

          it 'returns sync stats as payload' do
            expect(sync.payload).to include({ added: 0, removed: 0, updated: 0 })
          end
        end
      end

      context 'with a custom role' do
        let_it_be(:member_role) do
          create(:member_role, namespace: top_level_group, base_access_level: ::Gitlab::Access::GUEST)
        end

        before do
          stub_licensed_features(custom_roles: true)
          top_level_group.add_member(user, ::Gitlab::Access::GUEST, member_role_id: member_role.id)
        end

        it 'retains the correct access level, but removes the member_role connection' do
          expect(sync.payload).to include({ added: 1, removed: 0, updated: 1 })

          member = top_level_group.member(user)

          expect(member.access_level).to eq(::Gitlab::Access::GUEST)
          expect(member.member_role).to eq(nil)
        end
      end

      context 'when a group has no group links' do
        shared_examples 'removes the member' do
          before do
            group2.add_member(user, ::Gitlab::Access::DEVELOPER)
          end

          it 'reduces group member count by 1' do
            expect { sync }.to change { group2.members.count }.by(-1)
          end

          it 'removes the matching user' do
            sync

            expect(group2.members.pluck(:user_id)).not_to include(user.id)
          end

          it 'returns sync stats as payload' do
            expect(sync.payload).to include({ added: 2, removed: 1, updated: 0 })
          end
        end

        shared_examples 'retains the member' do
          before do
            group2.add_member(user, ::Gitlab::Access::REPORTER)
          end

          it 'does not change the group member count' do
            expect { sync }.not_to change { group2.members.count }
          end

          it 'retains the correct access level' do
            sync

            expect(group2.members.find_by(user_id: user.id).access_level)
              .to eq(::Gitlab::Access::REPORTER)
          end
        end

        context 'when manage_group_ids is present' do
          let_it_be(:manage_group_ids) { [group2.id] }

          it_behaves_like 'removes the member'
        end

        context 'in a group that is not managed' do
          let_it_be(:manage_group_ids) { [top_level_group.id, group1.id] }

          it_behaves_like 'retains the member'
        end

        context 'when no groups are managed' do
          let_it_be(:manage_group_ids) { [] }

          it_behaves_like 'retains the member'
        end
      end
    end

    context 'when the user has an access request' do
      before do
        create(:group_member, :access_request, group: group1, user: user)
      end

      it 'accepts the access request successfully' do
        expect(group1.members.find_by(user_id: user.id)).to be_nil

        sync

        expect(group1.members.find_by(user_id: user.id).access_level)
          .to eq(::Gitlab::Access::DEVELOPER)
      end
    end
  end
end
