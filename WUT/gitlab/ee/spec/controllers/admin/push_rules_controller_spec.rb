# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::PushRulesController, :with_current_organization, feature_category: :source_code_management do
  include StubENV

  let_it_be(:admin) { create(:admin) }

  before do
    sign_in(admin)
  end

  describe '#update' do
    let(:params) do
      {
        deny_delete_tag: "true", commit_message_regex: "any", branch_name_regex: "any",
        author_email_regex: "any", member_check: "true", file_name_regex: "any",
        max_file_size: "0", prevent_secrets: "true", commit_committer_check: "true", reject_unsigned_commits: "true",
        reject_non_dco_commits: "true", commit_committer_name_check: "true"
      }
    end

    before do
      stub_env('IN_MEMORY_APPLICATION_SETTINGS', 'false')
      stub_licensed_features(
        commit_committer_check: true,
        reject_unsigned_commits: true,
        reject_non_dco_commits: true,
        commit_committer_name_check: true)
    end

    shared_examples 'successful push rule update' do |count_change: 0|
      it 'updates sample push rule' do
        expect { patch :update, params: { push_rule: params } }.to change { PushRule.count }.by(count_change)

        expect(response).to redirect_to(admin_push_rule_path)
      end
    end

    context 'when a sample rule does not exist' do
      it_behaves_like 'successful push rule update', count_change: 1
      it 'assigns correct organization' do
        patch :update, params: { push_rule: params }

        expect(PushRule.global.organization).to eq(current_organization)
      end
    end

    context 'when a sample rule exists' do
      let_it_be(:push_rule) { create(:push_rule_sample, organization: current_organization) }

      it_behaves_like 'successful push rule update', count_change: 0
    end

    context 'when a sample rule exists but with a different org' do
      let_it_be(:organization) { create(:organization) }
      let_it_be(:push_rule) { create(:push_rule_sample, organization: organization) }

      it_behaves_like 'successful push rule update', count_change: 0

      it 'does not change organization' do
        expect { patch :update, params: { push_rule: params } }.not_to change { push_rule.reload.organization }
      end
    end

    it 'links push rule with application settings' do
      patch :update, params: { push_rule: params }

      expect(ApplicationSetting.current.push_rule_id).not_to be_nil
    end

    context 'push rules unlicensed' do
      before do
        stub_licensed_features(push_rules: false)
      end

      it 'returns 404' do
        patch :update, params: { push_rule: params }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe '#show' do
    it 'returns 200' do
      get :show

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'push rules unlicensed' do
      before do
        stub_licensed_features(push_rules: false)
      end

      it 'returns 404' do
        get :show

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
