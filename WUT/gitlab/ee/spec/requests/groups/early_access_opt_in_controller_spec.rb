# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::EarlyAccessOptInController, :saas, feature_category: :groups_and_projects do
  let_it_be(:owner) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let(:group) { create(:group) }

  describe 'GET show' do
    shared_examples 'unauthorized' do
      it 'renders index with 404 status code' do
        get group_early_access_opt_in_path(group)

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response).not_to render_template(:show)
      end
    end

    context 'when user is not authorized' do
      it_behaves_like 'unauthorized'
    end

    context 'when user is owner' do
      before do
        group.add_owner(owner)
        sign_in(owner)
      end

      it 'renders the show template' do
        get group_early_access_opt_in_path(group)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end
    end

    context 'when user is maintainer' do
      before do
        group.add_maintainer(maintainer)
        sign_in(maintainer)
      end

      it_behaves_like 'unauthorized'
    end

    context 'when user is developer' do
      before do
        group.add_developer(developer)
        sign_in(developer)
      end

      it_behaves_like 'unauthorized'
    end
  end

  describe 'POST create' do
    let(:join_service) { instance_double(Users::JoinEarlyAccessProgramService) }

    before do
      allow(Users::JoinEarlyAccessProgramService).to receive(:new).with(owner).and_return(join_service)
      allow(join_service).to receive(:execute)
      group.add_owner(owner)
      sign_in(owner)
    end

    it 'calls the JoinEarlyAccessProgramService' do
      expect(join_service).to receive(:execute)

      post group_early_access_opt_in_path(group)
    end

    it 'redirects to edit group path' do
      post group_early_access_opt_in_path(group)

      expect(response).to redirect_to(edit_group_path(group))
    end

    it 'sets a success flash message' do
      post group_early_access_opt_in_path(group)

      expect(flash[:success]).to include('You have been enrolled in the Early Access Program')
    end
  end
end
