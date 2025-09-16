# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::PersonalAccessTokensHelper, feature_category: :system_access do
  let(:group) do
    build(:group, max_personal_access_token_lifetime: group_level_max_personal_access_token_lifetime)
  end

  let(:group_level_max_personal_access_token_lifetime) { nil }
  let(:instance_level_max_personal_access_token_lifetime) { nil }
  let(:user) { build(:user) }
  let(:managed_user) { build(:user, managing_group: group) }

  before do
    allow(helper).to receive(:current_user) { user }
    stub_application_setting(max_personal_access_token_lifetime: instance_level_max_personal_access_token_lifetime)
  end

  describe '#personal_access_token_expiration_policy_enabled?' do
    subject { helper.personal_access_token_expiration_policy_enabled? }

    context 'with `personal_access_token_expiration_policy` licensed' do
      before do
        stub_licensed_features(personal_access_token_expiration_policy: true)
      end

      shared_examples_for 'instance level PAT expiry setting' do
        context 'the instance has an expiry setting' do
          let(:instance_level_max_personal_access_token_lifetime) { 20 }

          it { is_expected.to be_truthy }
        end

        context 'the instance does not have an expiry setting' do
          it { is_expected.to be_falsey }
        end
      end

      context 'when the current user belongs to a managed group' do
        let(:user) { managed_user }

        context 'when the managed group has a PAT expiry policy' do
          let(:group_level_max_personal_access_token_lifetime) { 10 }

          it { is_expected.to be_truthy }
        end

        context 'when the managed group does not have a PAT expiry setting' do
          it_behaves_like 'instance level PAT expiry setting'
        end
      end

      context 'when the current user does not belong to a managed group' do
        it_behaves_like 'instance level PAT expiry setting'
      end
    end

    context 'with `personal_access_token_expiration_policy` not licensed' do
      before do
        stub_licensed_features(personal_access_token_expiration_policy: false)
      end

      shared_examples_for 'instance level PAT expiry setting' do
        context 'the instance has an expiry setting' do
          let(:instance_level_max_personal_access_token_lifetime) { 20 }

          it { is_expected.to be_falsey }
        end

        context 'the instance does not have an expiry setting' do
          it { is_expected.to be_falsey }
        end
      end

      context 'when the current user belongs to a managed group' do
        let(:user) { managed_user }

        context 'when the managed group has a PAT expiry policy' do
          let(:group_level_max_personal_access_token_lifetime) { 10 }

          it { is_expected.to be_falsey }
        end

        context 'when the managed group does not have a PAT expiry setting' do
          it_behaves_like 'instance level PAT expiry setting'
        end
      end

      context 'when the current user does not belong to a managed group' do
        it_behaves_like 'instance level PAT expiry setting'
      end
    end
  end

  describe '#personal_access_token_max_expiry_date', :freeze_time do
    subject { helper.personal_access_token_max_expiry_date }

    shared_examples_for 'instance level PAT expiry setting' do
      context 'the instance has an expiry setting' do
        let(:instance_level_max_personal_access_token_lifetime) { 20 }

        it { is_expected.to eq(Date.current + 20.days) }
      end

      context 'the instance does not have an expiry setting' do
        it { is_expected.to be_nil }
      end
    end

    context 'when the current user belongs to a managed group' do
      let(:user) { managed_user }

      context 'when the managed group has a PAT expiry policy' do
        let(:group_level_max_personal_access_token_lifetime) { 10 }

        it { is_expected.to eq(Date.current + 10.days) }
      end

      context 'when the managed group does not have a PAT expiry setting' do
        it_behaves_like 'instance level PAT expiry setting'
      end
    end

    context 'when the current user does not belong to a managed group' do
      it_behaves_like 'instance level PAT expiry setting'
    end
  end

  shared_examples 'feature availability' do
    context 'when feature is licensed' do
      before do
        stub_licensed_features(feature => true)
      end

      it { is_expected.to be_truthy }
    end

    context 'with `personal_access_token_expiration_policy` not licensed' do
      before do
        stub_licensed_features(feature => false)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#personal_access_token_expiration_policy_licensed?' do
    subject { helper.personal_access_token_expiration_policy_licensed? }

    let(:feature) { :personal_access_token_expiration_policy }

    it_behaves_like 'feature availability'
  end

  describe '#max_personal_access_token_lifetime_in_days' do
    subject { helper.max_personal_access_token_lifetime_in_days }

    context 'when feature flag is enable' do
      it { is_expected.to eq(400) }
    end

    context 'with `personal_access_token_expiration_policy` not licensed' do
      before do
        stub_feature_flags(buffered_token_expiration_limit: false)
      end

      it { is_expected.to eq(365) }
    end
  end
end
