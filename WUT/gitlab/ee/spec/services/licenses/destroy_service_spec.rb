# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Licenses::DestroyService, feature_category: :plan_provisioning do
  subject(:destroy_license) { destroy_with(user) }

  let(:license) { create(:license) }

  let_it_be(:user) { create(:admin) }

  def destroy_with(user)
    described_class.new(license, user).execute
  end

  shared_examples 'license destroy' do
    it 'destroys a license' do
      destroy_license

      expect(License.where(id: license.id)).not_to exist
    end
  end

  shared_examples 'clear future subscriptions application setting' do
    it 'clears the future_subscriptions application setting' do
      expect(Gitlab::CurrentSettings.current_application_settings).to receive(:update)
        .with(future_subscriptions: [])

      destroy_license
    end
  end

  context 'when admin mode is enabled', :enable_admin_mode do
    it_behaves_like 'license destroy'
    it_behaves_like 'clear future subscriptions application setting'
    it_behaves_like 'call runner to handle the provision of add-ons'

    context 'with cloud license' do
      let(:license) { create(:license, cloud_licensing_enabled: true, plan: License::ULTIMATE_PLAN) }

      it_behaves_like 'license destroy'
      it_behaves_like 'clear future subscriptions application setting'
      it_behaves_like 'call runner to handle the provision of add-ons'
    end

    context 'with an active license that is not the current one' do
      before do
        if Gitlab.ee?
          allow(License).to receive(:current).and_return(create(:license))
        end
      end

      it_behaves_like 'license destroy'
      it_behaves_like 'call runner to handle the provision of add-ons'

      it 'does not clear the future_subscriptions application setting' do
        expect(Gitlab::CurrentSettings.current_application_settings).not_to receive(:update)
          .with(future_subscriptions: [])

        destroy_license
      end
    end
  end

  context 'when admin mode is disabled' do
    it 'raises not allowed error' do
      expect { destroy_with(user) }.to raise_error(::Gitlab::Access::AccessDeniedError)
    end
  end

  it 'raises an error if license is nil' do
    expect { described_class.new(nil, user).execute }.to raise_error ActiveRecord::RecordNotFound
  end

  it 'raises an error if the user is not an admin' do
    expect { destroy_with(create(:user)) }.to raise_error Gitlab::Access::AccessDeniedError
  end
end
