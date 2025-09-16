# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::User, :aggregate_failures, feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }
  let(:uid) { '1234' }
  let_it_be(:saml_provider) { create(:saml_provider) }
  let(:group) { saml_provider.group }
  let(:auth_hash) { OmniAuth::AuthHash.new(uid: uid, provider: 'group_saml', info: info_hash, extra: { raw_info: OneLogin::RubySaml::Attributes.new }) }
  let(:info_hash) do
    {
      name: generate(:name),
      email: generate(:email)
    }
  end

  subject(:oauth_user) do
    oauth_user = described_class.new(auth_hash, organization_id: organization.id)
    oauth_user.saml_provider = saml_provider

    oauth_user
  end

  def create_existing_identity
    create(:group_saml_identity, extern_uid: uid, saml_provider: saml_provider)
  end

  describe '#valid_sign_in?' do
    context 'with matching user for that group and uid' do
      let!(:identity) { create_existing_identity }

      it 'returns true' do
        is_expected.to be_valid_sign_in
      end
    end

    context 'with no matching user identity' do
      it 'returns false' do
        is_expected.not_to be_valid_sign_in
      end
    end
  end

  describe '#find_and_update!' do
    subject(:find_and_update) { oauth_user.find_and_update! }

    context 'with matching user for that group and uid' do
      let!(:identity) { create_existing_identity }

      it 'updates group membership' do
        expect { find_and_update }.to change { group.members.count }.by(1)
      end

      it 'returns the user' do
        expect(find_and_update).to eq identity.user
      end

      it 'does not mark the user as provisioned' do
        expect(find_and_update.provisioned_by_group).to be_nil
      end

      it 'calls Duo assignment updater' do
        expect(::Gitlab::Auth::GroupSaml::DuoAddOnAssignmentUpdater)
          .to receive(:new).with(identity.user, saml_provider.group, anything).and_call_original

        find_and_update
      end

      context 'when user is onboarding' do
        let(:user) { identity.user }

        before do
          stub_saas_features(onboarding: true)
          user.update!(onboarding_in_progress: true)
        end

        it 'finishes onboarding' do
          expect { find_and_update }.to change { user.reload.onboarding_in_progress }.to(false)
        end
      end

      context 'when user attributes are present' do
        before do
          identity.user.update!(can_create_group: false, projects_limit: 10)

          auth_hash[:extra][:raw_info] =
            OneLogin::RubySaml::Attributes.new(
              'can_create_group' => %w[true], 'projects_limit' => %w[20]
            )
        end

        context 'when user is managed by group', :saas do
          before do
            stub_licensed_features(domain_verification: true)
            identity.user.user_detail.update!(enterprise_group: group)
          end

          it 'updates the user can_create_group attribute' do
            expect(find_and_update.can_create_group).to eq(true)
          end

          it 'updates the user projects_limit attribute' do
            expect(find_and_update.projects_limit).to eq(20)
          end
        end

        context 'when user is not managed by group' do
          it 'does not update the user can_create_group attribute' do
            expect(find_and_update.can_create_group).to eq(false)
          end

          it 'does not update the user projects_limit attribute' do
            expect(find_and_update.projects_limit).to eq(10)
          end
        end
      end

      context 'when the user has multiple group saml identities' do
        let(:saml_provider2) { create(:saml_provider) }

        before do
          create(:group_saml_identity, extern_uid: uid, saml_provider: saml_provider2, user: identity.user)
        end

        it 'returns the user' do
          expect(find_and_update).to eq identity.user
        end
      end
    end

    context 'with no matching user identity' do
      context 'when a user does not exist' do
        it 'creates the user' do
          expect { find_and_update }.to change { User.count }.by(1)
        end

        it 'updates group membership' do
          expect { find_and_update }.to change { group.members.count }.by(1)
        end

        it 'does not attempt to finish onboarding' do
          expect(Onboarding::FinishService).not_to receive(:new)

          find_and_update
        end

        it 'does not confirm the user' do
          is_expected.not_to be_confirmed
        end

        it 'returns the correct user' do
          expect(find_and_update.email).to eq info_hash[:email]
        end

        it 'marks the user as provisioned by the group' do
          expect(find_and_update.provisioned_by_group).to eq group
        end

        it 'creates the user SAML identity' do
          expect { find_and_update }.to change { Identity.count }.by(1)
        end

        it 'sends user confirmation email' do
          expect { find_and_update }
            .to have_enqueued_mail(DeviseMailer, :confirmation_instructions)
        end

        context 'when a verified pages domain matches the user email domain', :saas do
          before do
            stub_licensed_features(domain_verification: true)
            create(:pages_domain, project: create(:project, group: group), domain: info_hash[:email].split('@')[1])
          end

          it 'confirms the user' do
            expect(find_and_update).to be_confirmed
          end

          it 'does not send user confirmation email' do
            expect { find_and_update }
              .not_to have_enqueued_mail(DeviseMailer, :confirmation_instructions)
          end
        end
      end

      context 'when a conflicting user already exists' do
        let!(:user) { create(:user, email: info_hash[:email]) }

        it 'does not update membership' do
          expect { find_and_update }.not_to change { group.members.count }
        end

        it 'returns a user with errors' do
          response = find_and_update

          expect(response).to be_a(User)
          expect(response.errors['email']).to include(_('has already been taken'))
        end

        context 'when user is an enterprise user of the group' do
          before do
            user.user_detail.update!(enterprise_group: saml_provider.group)
          end

          it 'updates group membership' do
            expect { find_and_update }.to change { group.members.count }.by(1)
          end

          it 'returns the user' do
            expect(find_and_update).to eq user
          end

          it 'adds group_saml identity' do
            expect { find_and_update }
              .to change { Identity.exists?(user: user, extern_uid: uid, provider: :group_saml, saml_provider_id: group.saml_provider.id) }
              .from(false).to(true)
          end

          context 'when user has group_saml identity with different extern_uid' do
            let!(:existing_group_saml_identity) { create(:group_saml_identity, user: user, extern_uid: 'some-other-name-id', saml_provider: saml_provider) }

            it "updates the identity's extern_uid" do
              expect { find_and_update }
                .to change { existing_group_saml_identity.reload.extern_uid }
                .from('some-other-name-id').to(uid)
            end
          end
        end

        context 'when user is an enterprise user of another group' do
          before do
            user.user_detail.update!(enterprise_group: create(:group))
          end

          it 'does not update membership' do
            expect { find_and_update }.not_to change { group.members.count }
          end

          it 'returns a user with errors' do
            response = find_and_update

            expect(response).to be_a(User)
            expect(response.errors['email']).to include(_('has already been taken'))
          end

          it 'does not add group_saml identity' do
            expect { find_and_update }.not_to change { Identity.count }
          end

          context 'when user has group_saml identity with different extern_uid' do
            let!(:existing_group_saml_identity) { create(:group_saml_identity, user: user, extern_uid: 'some-other-name-id', saml_provider: saml_provider) }

            it "does not update the identity's extern_uid" do
              expect { find_and_update }.not_to change { existing_group_saml_identity.reload.extern_uid }
            end
          end
        end
      end
    end
  end

  describe '#bypass_two_factor?' do
    it 'is false' do
      expect(subject.bypass_two_factor?).to eq false
    end
  end

  describe '#signup_identity_verification_enabled?', feature_category: :insider_threat do
    it 'is false' do
      expect(subject.signup_identity_verification_enabled?(anything)).to eq(false)
    end
  end
end
