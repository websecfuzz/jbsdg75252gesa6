# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionHelper, feature_category: :seat_cost_management do
  describe '#gitlab_com_subscription?' do
    context 'when GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
        stub_feature_flags(allow_self_hosted_features_for_com: true)
      end

      it 'returns false' do
        expect(helper.gitlab_com_subscription?).to be_falsy
      end

      context 'when allow_self_hosted_features_for_com is disabled' do
        before do
          stub_feature_flags(allow_self_hosted_features_for_com: false)
        end

        it 'returns true' do
          expect(helper.gitlab_com_subscription?).to be_truthy
        end
      end
    end

    context 'when not GitLab.com' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it 'returns false' do
        expect(helper.gitlab_com_subscription?).to be_falsy
      end
    end
  end
end
