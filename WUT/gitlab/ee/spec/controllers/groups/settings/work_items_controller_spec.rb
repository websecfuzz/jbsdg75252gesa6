# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::WorkItemsController, type: :controller, feature_category: :team_planning do
  let(:group) { create(:group) }
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe 'GET #show' do
    subject(:request) { get :show, params: { group_id: group.to_param } }

    context 'when user is not authorized' do
      before do
        stub_licensed_features(custom_fields: true, work_item_status: true)
      end

      it 'returns 404' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user is authorized' do
      before do
        group.add_maintainer(user)
      end

      context 'when custom_fields is not available' do
        before do
          stub_licensed_features(custom_fields: false)
        end

        it 'returns 404' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when custom_fields is available' do
        before do
          stub_licensed_features(custom_fields: true)
        end

        it 'renders the show template' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:show)
        end

        it 'uses the group_settings layout' do
          request

          expect(response).to render_template('layouts/group_settings')
        end
      end

      context 'when work_item_status is available' do
        before do
          stub_licensed_features(work_item_status: true)
        end

        it 'renders the show template' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:show)
        end
      end
    end
  end
end
