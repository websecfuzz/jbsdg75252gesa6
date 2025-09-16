# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UpdateLicenseDependenciesService, feature_category: :plan_provisioning do
  subject(:execute_service) do
    described_class.new(
      future_subscriptions: future_subscriptions,
      license: license,
      new_subscription: new_subscription
    ).execute
  end

  let_it_be(:organization) { create(:organization) }

  let!(:application_settings) { create(:application_setting) }
  let!(:license) { create(:license, cloud: true, data: gl_license.export) }
  let(:start_date) { Date.current }
  let(:gl_license) do
    build(
      :gitlab_license,
      :cloud,
      starts_at: start_date,
      restrictions: {
        add_on_products: {
          'duo_core' => [
            {
              'quantity' => 10,
              'started_on' => start_date.to_s,
              'expires_on' => (start_date + 11.months).to_s,
              'purchase_xid' => 'A-S00000001',
              'trial' => false
            }
          ]
        }
      }
    )
  end

  let(:future_subscriptions) { [] }
  let(:new_subscription) { false }

  before do
    stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')

    allow(Gitlab::CurrentSettings).to receive(:current_application_settings).and_return(application_settings)
  end

  context 'when there are no future subscriptions' do
    context 'when value is nil' do
      let(:future_subscriptions) { nil }

      it 'clears the future subscriptions' do
        expect(execute_service).to eq({ future_subscriptions: [] })

        expect(application_settings.reload.future_subscriptions).to eq([])
      end
    end

    context 'when value is an empty array' do
      it 'clears the future subscriptions' do
        expect(execute_service).to eq({ future_subscriptions: future_subscriptions })

        expect(application_settings.reload.future_subscriptions).to eq(future_subscriptions)
      end
    end
  end

  context 'when there are future subscriptions' do
    let(:future_subscriptions) do
      future_date = 4.days.from_now.to_date

      [
        {
          "cloud_license_enabled" => true,
          "offline_cloud_license_enabled" => false,
          "plan" => 'ultimate',
          "name" => 'User Example',
          "company" => 'Example Inc',
          "email" => 'user@example.com',
          "starts_at" => future_date.to_s,
          "expires_at" => (future_date + 1.year).to_s,
          "users_in_license_count" => 10
        }
      ]
    end

    it 'stores the future subscriptions' do
      expect(application_settings.future_subscriptions).to eq([])

      expect(execute_service).to eq({ future_subscriptions: future_subscriptions })

      expect(application_settings.reload.future_subscriptions).to eq(future_subscriptions)
    end

    context 'when saving the future subscriptions fails' do
      it 'logs error and returns an empty future_subscriptions array' do
        result = nil

        allow(Gitlab::CurrentSettings.current_application_settings).to receive(:update!)
          .and_raise(ActiveRecord::ActiveRecordError)

        expect(application_settings.future_subscriptions).to eq([])
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)

        expect { result = execute_service }.not_to raise_error

        expect(result).to eq({ future_subscriptions: [] })
        expect(application_settings.future_subscriptions).to eq([])
      end

      # continues the service execution
      it_behaves_like 'call runner to handle the provision of add-ons'
    end
  end

  context 'when new license does not contain a duo pro add-on purchase' do
    it_behaves_like 'call runner to handle the provision of add-ons'
  end

  context 'when new license contains a duo pro add-on purchase' do
    let(:gl_license) do
      build(
        :gitlab_license,
        :cloud,
        restrictions: { code_suggestions_seat_count: 1, subscription_name: 'A-S00000001' }
      )
    end

    it_behaves_like 'call runner to handle the provision of add-ons'
  end

  context 'when new subscription is true' do
    let(:new_subscription) { true }

    context 'when the subscription does not contain Duo Core' do
      let(:license_key) { build(:gitlab_license, :cloud).export }

      it 'does not auto enable the Duo Core features setting' do
        expect { execute_service }.to not_change(Ai::Setting.instance, :duo_core_features_enabled)
      end
    end

    context 'when the subscription contains Duo Core' do
      shared_examples 'do not enable Duo Core features setting' do
        it 'does not enable the Duo Core features setting' do
          ai_setting = Ai::Setting.instance

          expect { execute_service }.not_to change { ai_setting.reload.duo_core_features_enabled }
        end
      end

      context 'when license is nil' do
        let(:license) { nil }

        it_behaves_like 'do not enable Duo Core features setting'
      end

      context 'when license has not started yet' do
        let(:start_date) { Date.tomorrow }

        it_behaves_like 'do not enable Duo Core features setting'
      end

      context 'when user already updated the Duo Core features setting' do
        before do
          Ai::Setting.instance.update!(duo_core_features_enabled: duo_core_features_enabled)
        end

        context 'when the Duo Core features are already enabled' do
          let(:duo_core_features_enabled) { true }

          it_behaves_like 'do not enable Duo Core features setting'
        end

        context 'when the Duo Core features are disabled' do
          let(:duo_core_features_enabled) { false }

          it_behaves_like 'do not enable Duo Core features setting'
        end
      end

      context 'when there is no active Duo Core add-on' do
        let(:gl_license) do
          start_date = Date.current - 1.month

          build(
            :gitlab_license,
            :cloud,
            starts_at: start_date,
            restrictions: {
              add_on_products: {
                'duo_core' => [
                  {
                    'quantity' => 10,
                    'started_on' => start_date.to_s,
                    'expires_on' => Date.yesterday.to_s,
                    'purchase_xid' => 'A-S00000001',
                    'trial' => false
                  }
                ]
              }
            }
          )
        end

        it_behaves_like 'do not enable Duo Core features setting'
      end

      context 'when auto enabling the Duo Core features setting fails' do
        before do
          allow_next_instance_of(Ai::Setting) do |ai_setting|
            allow(ai_setting).to receive(:update!).and_raise(ActiveRecord::ActiveRecordError)
          end
        end

        it 'logs an error about it and continues the service execution' do
          result = nil

          expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)

          expect { result = execute_service }.not_to raise_error

          expect(result).to eq({ future_subscriptions: future_subscriptions })
        end
      end

      it 'auto enables the Duo Core features setting' do
        ai_setting = Ai::Setting.instance

        expect { execute_service }.to change { ai_setting.reload.duo_core_features_enabled }.from(nil).to(true)
      end
    end
  end
end
