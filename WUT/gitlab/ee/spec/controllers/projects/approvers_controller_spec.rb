# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ApproversController, feature_category: :source_code_management do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project) }

  let(:params) do
    {
      namespace_id: project.namespace.to_param,
      project_id: project.to_param,
      merge_request_id: merge_request.to_param,
      id: approver.id
    }
  end

  before_all do
    project.add_guest(user)
  end
  before do
    # Allow redirect_back_or_default to work
    request.env['HTTP_REFERER'] = '/'
    sign_in(user)
  end

  shared_examples 'removing an approver without access' do
    it 'returns a 404' do
      destroy_approver

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'does not destroy any approvers' do
      expect { destroy_approver }
        .not_to change { merge_request.reload.approvers.count }
    end

    context 'with removing approvers disallowed by project setting' do
      before_all do
        project.add_developer(user)
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it 'returns a 404' do
        destroy_approver

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'does not destroy any approvers' do
        expect { destroy_approver }
          .not_to change { merge_request.reload.approvers.count }
      end
    end
  end

  shared_examples 'when the user can update approvers' do
    it 'destroys the provided approver' do
      expect { destroy_approver }
        .to change { object.reload.approvers.count }.by(-1)
    end
  end

  describe '#destroy' do
    subject(:destroy_approver) { delete :destroy, params: params }

    context 'on a merge request' do
      let_it_be_with_reload(:approver) { create(:approver, target: merge_request) }

      it_behaves_like 'removing an approver without access'

      context 'when the user can update approvers' do
        let(:object) { merge_request }

        before_all do
          project.add_developer(user)
        end

        it_behaves_like 'when the user can update approvers'
      end
    end

    context 'on a project' do
      let_it_be_with_reload(:approver) { create(:approver, target: project) }
      let(:params) { super().except(:merge_request_id) }

      it_behaves_like 'removing an approver without access'

      context 'when the user can update approvers' do
        let(:object) { project }

        before_all do
          project.add_maintainer(user)
          project.update!(disable_overriding_approvers_per_merge_request: true)
        end

        it_behaves_like 'when the user can update approvers'
      end
    end
  end

  describe '#destroy_via_user_id' do
    let(:params) { super().merge(user_id: approver.user_id).except(:id) }

    context 'on a merge request' do
      let_it_be_with_reload(:approver) { create(:approver, target: merge_request) }

      subject(:destroy_approver) { delete :destroy_via_user_id, params: params }

      it_behaves_like 'removing an approver without access'

      context 'when the user can update approvers' do
        let(:object) { merge_request }

        before_all do
          project.add_developer(user)
        end

        it_behaves_like 'when the user can update approvers'
      end
    end
  end
end
