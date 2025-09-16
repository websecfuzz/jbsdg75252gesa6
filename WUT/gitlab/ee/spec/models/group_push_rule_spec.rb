# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupPushRule, :saas, feature_category: :source_code_management do
  subject(:group_push_rule) { create(:group_push_rule) }

  let_it_be(:premium_license) { create(:license, plan: License::PREMIUM_PLAN) }

  it_behaves_like 'a push ruleable model'

  describe 'associations' do
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
  end

  describe '#commit_signature_allowed?' do
    subject(:commit_signatured_allowed?) { group_push_rule.commit_signature_allowed?(commit) }

    let(:group_push_rule) { create(:group_push_rule, reject_unsigned_commits: reject_unsigned_commits) }
    let(:signed_commit) { instance_double(Commit, has_signature?: true) }
    let(:unsigned_commit) { instance_double(Commit, has_signature?: false) }

    shared_examples 'allows all commits' do
      context 'with signed commit' do
        let(:commit) { signed_commit }

        it { is_expected.to be(true) }
      end

      context 'with unsigned commit' do
        let(:commit) { unsigned_commit }

        it { is_expected.to be(true) }
      end
    end

    shared_examples 'rejects unsigned commits' do
      context 'with signed commit' do
        let(:commit) { signed_commit }

        it { is_expected.to be(true) }
      end

      context 'with unsigned commit' do
        let(:commit) { unsigned_commit }

        it { is_expected.to be(false) }
      end
    end

    context 'when enabled at group level' do
      let(:reject_unsigned_commits) { true }

      context 'and feature is licensed' do
        it_behaves_like 'rejects unsigned commits'
      end

      context 'and feature is not licensed' do
        before do
          stub_licensed_features(reject_unsigned_commits: false)
        end

        it_behaves_like 'allows all commits'
      end
    end

    context 'when disabled at group level' do
      let(:reject_unsigned_commits) { false }

      it_behaves_like 'allows all commits'
    end
  end

  describe '#available?' do
    subject(:available?) { group_push_rule.available?(:reject_unsigned_commits) }

    shared_examples 'an available group push rule' do
      it { is_expected.to be(true) }
    end

    shared_examples 'an unavailable group push rule' do
      it { is_expected.to be(false) }
    end

    context 'with GL.com plans' do
      let(:plan) { :free }
      let(:group) { create(:group) }
      let!(:gitlab_subscription) { create(:gitlab_subscription, plan, namespace: group) }
      let(:group_push_rule) { create(:group_push_rule, group: group) }

      before do
        stub_application_setting(check_namespace_plan: true)
      end

      context 'with different payment plans verifications' do
        context 'with a Bronze plan' do
          let(:plan) { :bronze }

          it_behaves_like 'an unavailable group push rule'
        end

        context 'with a Premium plan' do
          let(:plan) { :premium }

          it_behaves_like 'an available group push rule'
        end

        context 'with a Ultimate plan' do
          let(:plan) { :ultimate }

          it_behaves_like 'an available group push rule'
        end
      end
    end
  end
end
