# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::EpicsController, feature_category: :portfolio_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }

  before do
    stub_licensed_features(epics: true)
    sign_in(user)
  end

  describe 'GET #index' do
    subject(:get_index) { get group_epics_path(group) }

    context 'when epics are not licensed' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns not_found' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET #new' do
    subject(:get_new) { get new_group_epic_path(group) }

    it 'with feature flag disabled it still sets the epic flags to true' do
      get_new

      expect(response.body).to have_pushed_frontend_feature_flags(workItemEpics: true)
      expect(response).to have_gitlab_http_status(:success)
    end

    context 'when license is not available' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns not found' do
        get_new

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET #show' do
    context 'for work item epics' do
      it 'renders work item page' do
        get group_epic_path(group, epic)

        expect(response).to render_template('groups/epics/work_items_index')
        expect(assigns(:work_item)).to eq(epic.work_item)
        expect(response.body).to have_pushed_frontend_feature_flags(workItemEpics: true)
      end

      it 'renders json when requesting json response' do
        get group_epic_path(group, epic, format: :json)

        expect(response).to have_gitlab_http_status(:success)
        expect(response.media_type).to eq('application/json')
      end
    end

    context 'for summarize notes feature' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :summarize_comments, epic).and_return(summarize_notes_enabled)
      end

      context 'when feature is available set' do
        let(:summarize_notes_enabled) { true }

        it 'exposes the required feature flags' do
          get group_epic_path(group, epic)

          expect(response.body).to have_pushed_frontend_feature_flags(summarizeComments: true)
        end
      end

      context 'when feature is not available' do
        let(:summarize_notes_enabled) { false }

        it 'does not expose the feature flags' do
          get group_epic_path(group, epic)

          expect(response.body).not_to have_pushed_frontend_feature_flags(summarizeComments: true)
        end
      end
    end
  end
end
