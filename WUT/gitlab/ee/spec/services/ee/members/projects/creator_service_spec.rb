# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::Projects::CreatorService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:source) { create(:project) }
  let(:existing_role) { :guest }
  let!(:existing_member) { create(:project_member, existing_role, user: user, project: source) }

  describe '.add_member' do
    context 'when inviting or promoting a member to a billable role' do
      it_behaves_like 'billable promotion management feature'
    end

    context 'with the licensed feature for disable_invite_members' do
      let_it_be(:role) { :developer }
      let_it_be(:added_user) { create(:user) }

      shared_examples 'successful member creation' do
        it 'creates a new member' do
          member = described_class.add_member(source, added_user, role, current_user: current_user)
          expect(member).to be_persisted
        end
      end

      shared_examples 'failed member creation' do
        it 'does not create a new member' do
          member = described_class.add_member(source, added_user, role, current_user: current_user)
          expect(member).not_to be_persisted
          expect(member.errors.full_messages).to include(/not authorized to create member/)
        end
      end

      context 'when the user is a project maintainer' do
        let_it_be(:current_user) { create(:user) }

        before_all do
          source.add_maintainer(current_user)
        end

        context 'and the licensed feature is available' do
          before do
            stub_licensed_features(disable_invite_members: true)
          end

          context 'and the setting disable_invite_members is ON' do
            before do
              stub_application_setting(disable_invite_members: true)
            end

            it_behaves_like 'failed member creation'
          end

          context 'and the setting disable_invite_members is OFF' do
            before do
              stub_application_setting(disable_invite_members: false)
            end

            it_behaves_like 'successful member creation'
          end
        end

        context 'and the licensed feature is unavailable' do
          before do
            stub_licensed_features(disable_invite_members: false)
            stub_application_setting(disable_invite_members: true)
          end

          it_behaves_like 'successful member creation'
        end
      end

      context 'when the user is an admin and the setting disable_invite_members is ON' do
        let_it_be(:current_user) { create(:admin) }

        before do
          stub_licensed_features(disable_invite_members: true)
          stub_application_setting(disable_invite_members: true)
        end

        context 'with admin mode enabled', :enable_admin_mode do
          it_behaves_like 'successful member creation'
        end

        it_behaves_like 'failed member creation'
      end
    end
  end

  describe '.add_members' do
    context 'when inviting or promoting a member to a billable role' do
      it_behaves_like 'billable promotion management for multiple users'
    end
  end
end
