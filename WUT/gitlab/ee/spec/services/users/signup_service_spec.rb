# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::SignupService, feature_category: :system_access do
  let_it_be(:user) { create(:user, onboarding_status_setup_for_company: true) }
  let(:params) { {} }
  let(:update_params) { { onboarding_status_role: 0 }.merge(params) }
  let(:user_return_to) { nil }

  describe '#execute' do
    let(:updated_user) { execute[:user].reset }

    subject(:execute) { described_class.new(user, params: update_params, user_return_to: user_return_to).execute }

    it 'logs the passed params' do
      allow(Gitlab::AppLogger).to receive(:info).and_call_original
      expect(Gitlab::AppLogger).to receive(:info).with(
        message: "#{described_class.name}: user_return_to: #{user_return_to}, params: #{update_params.to_json}",
        user_id: user.id)

      execute
    end

    context 'when stop_welcome_redirection feature flag is disabled' do
      before do
        stub_feature_flags(stop_welcome_redirection: false)
      end

      it 'does not log the passed params' do
        expect(Gitlab::AppLogger).not_to receive(:info)

        execute
      end
    end

    context 'when updating name' do
      let(:params) { { name: 'New Name' } }

      it 'updates the name attribute' do
        expect(execute).to be_success
        expect(updated_user.name).to eq('New Name')
      end

      context 'when name is missing' do
        let(:params) { { name: '' } }

        it 'returns an error result' do
          expect(updated_user.name).not_to be_blank
          expect(execute).to be_error
          expect(execute.message).to include("Name can't be blank")
        end
      end
    end

    context 'when updating onboarding_status_role' do
      let(:params) { { onboarding_status_role: 1 } }

      it 'updates the onboarding_status_role attribute' do
        expect(execute).to be_success
        expect(updated_user.onboarding_status_role_name).to eq('development_team_lead')
      end

      context 'when onboarding_status_role is missing' do
        let(:params) { { onboarding_status_role: nil } }

        it 'returns an error result' do
          expect(execute).to be_error
          expect(execute.message).to include("User detail onboarding status role can't be blank")
        end
      end
    end

    context 'when updating setup_for_company' do
      let(:params) { { onboarding_status_setup_for_company: 'true' } }

      it 'updates the setup_for_company attribute' do
        expect(execute).to be_success
        expect(updated_user.onboarding_status_setup_for_company).to be(true)
      end

      context 'when onboarding_status_setup_for_company is missing' do
        let(:params) { { onboarding_status_setup_for_company: '' } }

        it 'returns a successful result and sets onboarding_status_setup_for_company to false' do
          expect(execute).to be_success
          expect(updated_user.onboarding_status_setup_for_company).to be false
        end
      end
    end

    context 'with iterable concerns' do
      context 'when eligible for iterable trigger' do
        let(:params) do
          {
            onboarding_status_registration_objective: 2,
            onboarding_status_setup_for_company: 'false',
            jobs_to_be_done_other: '_jobs_to_be_done_other_'
          }
        end

        let(:extra_iterable_params) { {} }
        let(:iterable_params) do
          {
            comment: '_jobs_to_be_done_other_',
            jtbd: 'code_storage',
            opt_in: user.onboarding_status_email_opt_in,
            preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
            product_interaction: 'Personal SaaS Registration',
            provider: 'gitlab',
            role: 'software_developer',
            setup_for_company: false,
            uid: user.id,
            work_email: user.email
          }.merge(extra_iterable_params).stringify_keys
        end

        before do
          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:generate_iterable).with(iterable_params).and_return({ success: true })
        end

        it 'initiates iterable trigger creation', :sidekiq_inline do
          expect(::Onboarding::CreateIterableTriggerWorker)
            .to receive(:perform_async).with(iterable_params).and_call_original

          execute
        end

        context 'with existing_plan for invite registrations', :saas do
          let(:extra_iterable_params) { { product_interaction: 'Invited User', existing_plan: 'ultimate' } }

          before do
            user.update!(onboarding_status_registration_type: 'invite')
            create(:group_with_plan, plan: :ultimate_plan, developers: user)
          end

          it 'initiates iterable trigger creation', :sidekiq_inline do
            expect(::Onboarding::CreateIterableTriggerWorker)
              .to receive(:perform_async).with(iterable_params).and_call_original

            execute
          end
        end
      end

      context 'when not eligible for iterable trigger' do
        before do
          user.update!(onboarding_status_registration_type: 'trial')
        end

        it 'does not initiate iterable trigger creation' do
          expect(::Onboarding::CreateIterableTriggerWorker).not_to receive(:perform_async)

          execute
        end
      end
    end

    context 'with onboarding concerns' do
      before do
        stub_saas_features(onboarding: true)
      end

      context 'when onboarding is ended' do
        let(:params) { { onboarding_in_progress: false } }

        before do
          user.update!(onboarding_in_progress: true)
        end

        it 'ends onboarding' do
          expect { execute }.to change { user.onboarding_in_progress }.from(true).to(false)
        end
      end

      context 'when onboarding continues' do
        let(:params) { { onboarding_in_progress: true } }

        before do
          user.update!(onboarding_in_progress: true)
        end

        it 'does not end onboarding' do
          expect { execute }.not_to change { user.onboarding_in_progress }
        end
      end

      context 'when registration_type converts to a trial' do
        let(:params) { { onboarding_status_registration_type: 'trial' } }

        before do
          user.update!(onboarding_status_registration_type: 'free')
        end

        it 'changes registration_type to trial' do
          expect { execute }.to change { user.onboarding_status_registration_type }.from('free').to('trial')
        end
      end

      context 'when registration_type remains unchanged' do
        before do
          user.update!(onboarding_status_registration_type: 'free')
        end

        it 'does not change the registration_type' do
          expect { execute }.not_to change { user.onboarding_status_registration_type }
        end
      end
    end

    context 'for logged errors' do
      let(:params) { { onboarding_status: { unsupported_key: '_some_value_' } } }

      it 'logs the errors from active record and the onboarding_status' do
        expect(Gitlab::AppLogger).to receive(:error).with(/#{described_class}: Could not save/)

        execute
      end
    end
  end
end
