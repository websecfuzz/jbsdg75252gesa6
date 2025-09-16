# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::NamespaceSettings::AssignAttributesService, feature_category: :groups_and_projects do
  let_it_be_with_reload(:nested_group) { create(:group, :nested) }
  let_it_be_with_reload(:group) { nested_group.parent }
  let_it_be_with_reload(:user) { create(:user) }

  subject(:update_settings) { NamespaceSettings::AssignAttributesService.new(user, group, params).execute }

  describe '#execute' do
    context 'when disable_invite_members param present' do
      let(:params) { { disable_invite_members: true } }

      context 'as a non-owner' do
        it 'does not change settings' do
          group.update!(disable_invite_members: true)
          group.save!

          update_settings

          expect(group.disable_invite_members?).to eq(true)
        end
      end

      context 'as a group owner' do
        before_all do
          group.add_owner(user)
        end

        it 'changes settings' do
          update_settings

          expect(group.disable_invite_members?).to eq(true)
        end
      end

      context 'as a non-group owner' do
        before_all do
          group.add_maintainer(user)
        end

        it "does not change settings" do
          expect { update_settings }
            .not_to(change { group.disable_invite_members? })
        end
      end

      context 'when not top-level group' do
        let(:group) { nested_group }

        it 'does not change settings' do
          expect { update_settings }
            .not_to(change { group.disable_invite_members? })
        end
      end
    end

    context 'when prevent_forking_outside_group param present' do
      let(:params) { { prevent_forking_outside_group: true } }

      context 'as a normal user' do
        it 'does not change settings' do
          update_settings

          expect { group.save! }
            .not_to(change { group.namespace_settings.prevent_forking_outside_group })
        end

        it 'registers an error' do
          update_settings

          expect(group.errors[:prevent_forking_outside_group]).to include('Prevent forking setting was not saved')
        end
      end

      context 'as a group owner' do
        before_all do
          group.add_owner(user)
        end

        context 'for a group that does not have prevent forking feature' do
          it 'does not change settings' do
            update_settings

            expect { group.save! }
              .not_to(change { group.namespace_settings.prevent_forking_outside_group })
          end

          it 'registers an error' do
            update_settings

            expect(group.errors[:prevent_forking_outside_group]).to include('Prevent forking setting was not saved')
          end
        end

        context 'for a group that has prevent forking feature' do
          before do
            stub_licensed_features(group_forking_protection: true)
          end

          it 'changes settings' do
            update_settings
            group.save!

            expect(group.namespace_settings.reload.prevent_forking_outside_group).to eq(true)
          end
        end
      end
    end

    context 'when service_access_tokens_expiration_enforced param present' do
      let(:params) { { service_access_tokens_expiration_enforced: false } }

      before_all do
        group.add_owner(user)
      end

      context 'when service accounts is not available' do
        it 'does not change settings' do
          expect { update_settings }
            .not_to(change { group.namespace_settings.reload.service_access_tokens_expiration_enforced })
        end

        it 'registers an error' do
          update_settings

          expect(group.errors[:service_access_tokens_expiration_enforced])
            .to include('Service access tokens expiration enforced setting was not saved')
        end
      end

      context 'when service accounts is available' do
        before do
          stub_licensed_features(service_accounts: true)
        end

        it 'changes settings' do
          update_settings

          expect(group.namespace_settings.attributes["service_access_tokens_expiration_enforced"])
            .to eq(false)
        end

        context 'when group is not top level group' do
          let(:group) { nested_group }

          it 'registers an error' do
            update_settings

            expect(group.errors[:service_access_tokens_expiration_enforced])
              .to include('Service access tokens expiration enforced setting was not saved')
          end
        end
      end
    end

    shared_examples 'ignores web-based commit signing parameters' do
      it 'does not change settings' do
        expect { update_settings }
          .not_to(
            change do
              group.namespace_settings.slice(
                :web_based_commit_signing_enabled,
                :lock_web_based_commit_signing_enabled
              )
            end
          )
      end
    end

    shared_examples 'adds web-based commit signing error' do |expected_error|
      it 'adds an error to namespace_settings' do
        update_settings

        expect(group.namespace_settings.errors[:web_based_commit_signing_enabled])
          .to include(expected_error)
      end
    end

    context 'when web_based_commit_signing_enabled param is present' do
      before_all do
        group.add_owner(user)
      end
      let(:params) { { web_based_commit_signing_enabled: true } }

      context 'when set to true' do
        it 'sets web_based_commit_signing_enabled and locks it' do
          update_settings

          expect(group.namespace_settings.web_based_commit_signing_enabled).to eq(true)
          expect(group.namespace_settings.lock_web_based_commit_signing_enabled).to eq(true)
        end
      end

      context 'when set to false' do
        let(:params) { { web_based_commit_signing_enabled: false } }

        it 'sets web_based_commit_signing_enabled and unlocks it' do
          update_settings

          expect(group.namespace_settings.web_based_commit_signing_enabled).to eq(false)
          expect(group.namespace_settings.lock_web_based_commit_signing_enabled).to eq(false)
        end
      end

      context 'when group is not root' do
        let(:group) { nested_group }

        it_behaves_like 'ignores web-based commit signing parameters'

        it_behaves_like 'adds web-based commit signing error', 'only available on top-level groups.'
      end

      context 'when user is not admin' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'ignores web-based commit signing parameters'

        it_behaves_like 'adds web-based commit signing error', 'can only be changed by a group admin.'
      end
    end

    context 'when web_based_commit_signing_enabled param is not present' do
      let(:params) { {} }

      it_behaves_like 'ignores web-based commit signing parameters'
    end
  end
end
