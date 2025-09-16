# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'merge requests creations', feature_category: :code_review_workflow do
  describe 'POST /:namespace/:project/merge_requests' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user, :with_namespace, developer_of: group) }
    let_it_be(:project) { create(:project, :repository, group: group) }

    let(:merge_request) { MergeRequest.last }
    let(:create_merge_request_params) do
      {
        namespace_id: project.namespace.to_param,
        project_id: project,
        merge_request: {
          source_branch: 'feature',
          target_branch: 'master',
          title: 'Test merge request',
          description: description
        }
      }
    end

    subject(:send_request) do
      post namespace_project_merge_requests_path(create_merge_request_params)
    end

    before do
      login_as(user)
    end

    describe 'Duo code review assignment handling' do
      include_examples 'handle quickactions without Duo access'

      context 'when automatic Duo code review is enabled' do
        let(:duo_bot) { ::Users::Internal.duo_code_review_bot }
        let(:project) { create(:project, :repository, group: group) }
        let(:description) { "" }
        let(:duo_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

        before do
          create(:gitlab_subscription_add_on_purchase,
            namespace: project.namespace,
            add_on: duo_add_on)
          ai_features_service = instance_double(::Projects::AiFeatures)
          allow(ai_features_service).to receive(:review_merge_request_allowed?).with(user).and_return(has_duo_access)
          allow(::Projects::AiFeatures).to receive(:new).and_return(ai_features_service)

          project.project_setting.update_attribute(:auto_duo_code_review_enabled, true)
        end

        context 'when user lacks Duo access' do
          let(:has_duo_access) { false }

          it 'does not assign Duo bot as a reviewer and shows access error message' do
            send_request

            expect(response).to redirect_to(project_merge_request_path(project, merge_request))

            follow_redirect!

            expect(flash[:alert]).to include("Your account doesn't have GitLab Duo access")
            expect(merge_request.reload.reviewers).not_to include(duo_bot)
          end
        end

        context 'when user has Duo access' do
          let(:has_duo_access) { true }

          it 'assigns Duo bot as a reviewer' do
            send_request

            expect(response).to redirect_to(project_merge_request_path(project, merge_request))

            follow_redirect!

            expect(flash[:alert]).to be_nil
            expect(merge_request.reload.reviewers).to include(duo_bot)
          end
        end
      end
    end
  end
end
