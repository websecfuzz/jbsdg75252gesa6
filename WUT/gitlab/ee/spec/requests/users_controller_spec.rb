# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UsersController, feature_category: :user_profile do
  let_it_be(:user) { create(:user) }

  before do
    sign_in user
  end

  describe '#available_group_templates' do
    subject(:perform_request) do
      get user_available_group_templates_path(user.username)
    end

    context 'when pagination' do
      before do
        allow(Kaminari.config).to receive(:default_per_page).and_return(1)

        2.times do |i|
          group = create(:group, name: "group#{i}")
          subgroup = create(:group, parent: group, name: "subgroup#{i}")
          create(:project, group: subgroup)

          group.update!(custom_project_templates_group_id: subgroup.id)
          group.add_maintainer(user)
        end
      end

      it 'shows the first page of the pagination' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('group0')
        expect(response.body).not_to include('group1')
      end
    end

    context 'when project is a group template project' do
      let_it_be_with_reload(:group) { create(:group, name: 'group-parent') }
      let_it_be_with_reload(:subgroup) { create(:group, parent: group, name: 'subgroup') }
      let_it_be_with_reload(:project) { create(:project, group: subgroup, name: 'visible-project') }

      before_all do
        group.update!(custom_project_templates_group_id: subgroup.id)
        group.add_maintainer(user)
      end

      it 'shows a group and a project' do
        perform_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('group-parent')
        expect(response.body).to include('visible-project')
      end

      context 'when project is archived' do
        before do
          project.update!(archived: true)
        end

        it 'does not show archived projects and empty groups' do
          perform_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).not_to include('group-parent')
          expect(response.body).not_to include('visible-project')
        end
      end
    end
  end
end
