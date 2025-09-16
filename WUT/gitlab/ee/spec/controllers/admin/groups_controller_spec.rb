# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::GroupsController, feature_category: :continuous_integration do
  let(:admin) { create(:admin) }
  let(:group) { create(:group) }

  before do
    sign_in(admin)
  end

  describe 'POST #reset_runner_minutes', feature_category: :hosted_runners do
    subject { post :reset_runners_minutes, params: { id: group } }

    before do
      allow_next_instance_of(Ci::Minutes::ResetUsageService) do |instance|
        allow(instance).to receive(:execute).and_return(clear_runners_minutes_service_result)
      end
    end

    context 'when the reset is successful' do
      let(:clear_runners_minutes_service_result) { true }

      it 'redirects to group path' do
        subject

        expect(response).to redirect_to(admin_group_path(group))
        expect(controller).to set_flash[:notice]
      end
    end
  end

  describe 'POST #create', :with_current_organization do
    subject(:post_request) { post :create, params: { group: params } }

    context 'when repository size limit is provided' do
      let(:params) { { path: 'test', name: 'test', repository_size_limit: '5000' } }

      it 'creates a group with a correct repository limit' do
        expect { post_request }.to change { Group.count }.by(1)

        expect(Group.last.repository_size_limit).to eq(5000.megabytes)
      end
    end
  end

  describe 'PUT #update' do
    it 'converts the user entered MiB value into bytes' do
      put :update, params: { id: group, group: { repository_size_limit: '5000' } }

      expect(controller).to set_flash[:notice].to 'Group was successfully updated.'
      expect(response).to redirect_to(admin_group_path(group))
      expect(group.reload.repository_size_limit).to eq(5000.megabytes)
    end
  end
end
