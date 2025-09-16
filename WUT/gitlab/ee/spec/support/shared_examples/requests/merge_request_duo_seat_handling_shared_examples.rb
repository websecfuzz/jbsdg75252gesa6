# frozen_string_literal: true

RSpec.shared_examples 'handle quickactions without Duo access' do
  let(:duo_bot) { ::Users::Internal.duo_code_review_bot }

  before do
    ai_features_service = instance_double(::Projects::AiFeatures)
    allow(ai_features_service).to receive(:review_merge_request_allowed?).with(user).and_return(has_duo_access)
    allow(::Projects::AiFeatures).to receive(:new).and_return(ai_features_service)
  end

  context 'when using /assign_reviewer with Duo bot' do
    context 'when user lacks Duo access' do
      let(:has_duo_access) { false }

      context 'when only Duo was assigned as a reviewer' do
        let(:description) { "/assign_reviewer @#{duo_bot.username}" }

        it 'filters out Duo bot and shows access error message' do
          send_request

          expect(response).to redirect_to(project_merge_request_path(project, merge_request))

          follow_redirect!

          expect(flash[:alert]).to include("Your account doesn't have GitLab Duo access")
          expect(merge_request.reload.reviewers).not_to include(duo_bot)
        end
      end

      context 'when a user was assigned with Duo bot' do
        let(:description) { "/assign_reviewer @#{duo_bot.username} @#{user.username}" }

        it 'still assigns a regular reviewer' do
          send_request

          expect(response).to redirect_to(project_merge_request_path(project, merge_request))

          follow_redirect!

          expect(flash[:alert]).to include("Your account doesn't have GitLab Duo access")

          expect(merge_request.reload.reviewers).to include(user)
          expect(merge_request.reload.reviewers).not_to include(duo_bot)
        end
      end
    end

    context 'when user has Duo access' do
      let(:has_duo_access) { true }
      let(:description) { "/assign_reviewer @#{duo_bot.username}" }

      it 'assigns Duo bot as reviewer' do
        send_request

        expect(response).to redirect_to(project_merge_request_path(project, merge_request))

        follow_redirect!

        expect(flash[:alert]).to be_nil
        expect(merge_request.reload.reviewers).to include(duo_bot)
      end
    end
  end

  context 'when using /request_review with Duo bot' do
    let(:description) { "/request_review @#{duo_bot.username}" }

    context 'when user lacks Duo access' do
      let(:has_duo_access) { false }

      context 'when only requesting a review from Duo' do
        it 'filters out Duo bot and shows access error message' do
          send_request

          expect(response).to redirect_to(project_merge_request_path(project, merge_request))

          follow_redirect!

          expect(flash[:alert]).to include("Your account doesn't have GitLab Duo access")
          expect(merge_request.reload.reviewers).not_to include(duo_bot)
        end
      end

      context 'when also requesting a review from a regular user' do
        let(:description) { "/request_review @#{duo_bot.username} @#{user.username}" }

        it 'still requests a review from regular reviewers along with Duo error message' do
          send_request

          expect(response).to redirect_to(project_merge_request_path(project, merge_request))

          follow_redirect!

          expect(flash[:alert]).to include("Your account doesn't have GitLab Duo access")
          expect(merge_request.reload.reviewers).to include(user)
          expect(merge_request.reload.reviewers).not_to include(duo_bot)
        end
      end
    end

    context 'when user has Duo access' do
      let(:description) { "/request_review @#{duo_bot.username}" }
      let(:has_duo_access) { true }

      it 'request review from Duo bot' do
        send_request

        expect(response).to redirect_to(project_merge_request_path(project, merge_request))

        follow_redirect!

        expect(flash[:alert]).to be_nil
        expect(merge_request.reload.reviewers).to include(duo_bot)
      end
    end
  end
end
