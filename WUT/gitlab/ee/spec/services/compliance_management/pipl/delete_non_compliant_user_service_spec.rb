# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::DeleteNonCompliantUserService,
  :saas,
  feature_category: :compliance_management do
  subject(:execute) { described_class.new(pipl_user: pipl_user, current_user: deleting_user).execute }

  let_it_be_with_reload(:pipl_user) { create(:pipl_user, :deletable) }
  let_it_be_with_reload(:user) { pipl_user.user }
  let(:deleting_user) { create(:user, :admin) }

  shared_examples 'does not delete the user' do
    it 'does not schedule a deletion migration' do
      expect { execute }.not_to change { user.reload.ghost_user_migration.present? }
    end
  end

  shared_examples 'has a validation error' do |message|
    it 'returns an error with a descriptive message' do
      result = execute

      expect(result.error?).to be(true)
      expect(result.message).to include(message)
    end
  end

  describe '#execute' do
    context 'when admin_mode is disabled', :do_not_mock_admin_mode_setting do
      context 'when checks fail' do
        context 'when the feature is not available on the instance' do
          before do
            stub_saas_features(pipl_compliance: false)
          end

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error', "Pipl Compliance is not available on this instance"
        end

        context 'when the enforce_pipl_compliance setting is disabled' do
          before do
            stub_ee_application_setting(enforce_pipl_compliance: false)
          end

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error', "You don't have the required permissions to " \
            "perform this action or this feature is disabled"
        end

        context 'when the pipl_user is not blocked' do
          before do
            pipl_user.user.update!(state: :active)
          end

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error', "User is not blocked"
        end

        context 'when the deleting user is not an admin' do
          before do
            deleting_user.update!(admin: false)
          end

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error',
            "You don't have the required permissions to perform this " \
              "action or this feature is disabled"
        end

        context 'when the pipl deletion threshold has not passed' do
          let(:pipl_user) { create(:pipl_user, user: deleting_user) }

          it_behaves_like 'does not delete the user'
          it_behaves_like 'has a validation error',
            "Pipl deletion threshold has not been exceeded for user:"
        end
      end

      context 'when the data is valid' do
        let(:pipl_user) { create(:pipl_user, :deletable) }

        it 'schedules user deletion', :sidekiq_inline do
          result = execute

          expect(result.error?).to be(false)
          expect(pipl_user.user.reload.ghost_user_migration.present?).to be(true)
          expect(pipl_user.user.reload.ghost_user_migration.hard_delete?).to be(false)
        end
      end
    end

    context 'when admin mode is enabled' do
      it_behaves_like 'does not delete the user'
      it_behaves_like 'has a validation error', "You don't have the required permissions to " \
        "perform this action or this feature is disabled"

      context 'when the user is in the admin_mode' do
        let(:pipl_user) { create(:pipl_user, :deletable) }

        it 'schedules user deletion', :sidekiq_inline, :enable_admin_mode do
          result = execute

          expect(result.error?).to be(false)
          expect(pipl_user.user.reload.ghost_user_migration.present?).to be(true)
        end

        context 'when user has public projects', :enable_admin_mode do
          let(:user_namespace) { pipl_user.user.reload.namespace }
          let(:public_user_project_no_repository) { create(:project, namespace: user_namespace) }

          before do
            public_user_project_no_repository.visibility_level = Gitlab::VisibilityLevel::PUBLIC
            public_user_project_no_repository.save!

            stub_container_registry_config(enabled: false)
          end

          context 'when project has no repository associated' do
            it 'schedules user deletion', :sidekiq_inline do
              result = execute

              expect(result.error?).to be(false)
              expect(pipl_user.user.reload.ghost_user_migration.present?).to be(true)
              expect(pipl_user.user.reload.ghost_user_migration.hard_delete?).to be(false)
            end
          end

          context 'when project has commits less than 5' do
            let(:repository) { instance_double(Repository, root_ref: 'master', empty?: false) }

            before do
              allow(public_user_project_no_repository).to receive(:repository).and_return(repository)
            end

            it 'schedules user deletion', :sidekiq_inline do
              result = execute

              expect(result.error?).to be(false)
              expect(pipl_user.user.reload.ghost_user_migration.present?).to be(true)
              expect(pipl_user.user.reload.ghost_user_migration.hard_delete?).to be(false)
            end
          end

          context 'when project has commits greater than 5' do
            let(:public_user_project_with_repository) do
              create(:project, :repository, namespace: user_namespace)
            end

            before do
              public_user_project_with_repository.statistics.refresh!

              public_user_project_with_repository.visibility_level = Gitlab::VisibilityLevel::PUBLIC
              public_user_project_with_repository.save!
            end

            it_behaves_like 'does not delete the user'

            it "returns an error with a descriptive message" do
              result = execute

              expect(result.error?).to be(true)
              expect(result.message).to include("User has active public projects and cannot be deleted." \
                "Please unlink the public projects or move the user the paid namespace")
              expect(pipl_user.state).to eq("deletion_needs_to_be_reviewed")
            end
          end
        end
      end
    end
  end
end
