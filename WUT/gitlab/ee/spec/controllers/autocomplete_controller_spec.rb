# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutocompleteController do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, namespace: user.namespace) }

  context 'GET users', feature_category: :user_profile do
    let_it_be(:user2) { create(:user) }
    let_it_be(:non_member) { create(:user) }

    context 'project members' do
      before do
        project.add_developer(user2)
        sign_in(user)
      end

      describe 'GET #users with suggested users' do
        let_it_be(:suggested_user) { create(:user) }
        let_it_be(:merge_request) { create(:merge_request, source_project: project) }

        let(:request_common_params) do
          {
            active: 'true',
            project_id: project.id,
            merge_request_iid: merge_request.iid,
            current_user: true
          }
        end

        let(:request_params) { request_common_params }

        before do
          project.add_developer(suggested_user)
          merge_request.build_predictions
          merge_request.predictions.update!(suggested_reviewers: { reviewers: [suggested_user.username] })

          allow(controller).to receive(:suggested_reviewers_available?).and_return(true)
        end

        shared_examples 'feature available' do
          it 'returns the suggested reviewers' do
            get(:users, params: request_params)

            expect(json_response).to be_kind_of(Array)
            expect(json_response.size).to eq(3)
            expect(json_response.map { |user| user['suggested'] }).to match_array([nil, nil, true])
          end
        end

        shared_examples 'feature unavailable' do
          it 'returns no suggested reviewers' do
            get(:users, params: request_params)

            expect(json_response).to be_kind_of(Array)
            expect(json_response.size).to eq(3)
            expect(json_response.map { |user| user['suggested'] }).to match_array([nil, nil, nil])
          end
        end

        include_examples 'feature available'

        context 'when suggested reviewers is unavailable for project' do
          before do
            allow(controller).to receive(:suggested_reviewers_available?).and_return(false)
          end

          include_examples 'feature unavailable'
        end

        context 'when search param is not blank' do
          let(:request_params) { request_common_params.merge(search: suggested_user.username) }

          it 'returns no suggested reviewers' do
            get(:users, params: request_params)

            expect(json_response.map { |user| user['suggested'] }).to match_array([nil])
          end
        end

        context 'when merge_request_iid is blank' do
          let(:request_params) { request_common_params.except(:merge_request_iid) }

          include_examples 'feature unavailable'
        end

        context 'when merge_request is closed' do
          let_it_be(:merge_request) { create(:merge_request, :closed, source_project: project) }

          include_examples 'feature unavailable'
        end

        context 'when merge_request has been merged' do
          let_it_be(:merge_request) { create(:merge_request, :merged, source_project: project) }

          include_examples 'feature unavailable'
        end
      end
    end
  end

  context 'groups', feature_category: :groups_and_projects do
    before do
      sign_in(user)
    end

    it 'responds with the results from Autocomplete::ProjectInvitedGroupsFinder' do
      stubbed_results = build_list(:group, 2)
      allow_next_instance_of(Autocomplete::ProjectInvitedGroupsFinder) do |finder|
        allow(finder).to receive(:execute).and_return(stubbed_results)
      end

      get(:project_groups, params: { project_id: project.id })

      expect(json_response).to match_array(stubbed_results.map { |group| a_hash_including("id" => group.id) })
    end

    context "while fetching all groups belonging to a project the current user cannot access" do
      it 'responds with not found' do
        allow_next_instance_of(Autocomplete::ProjectInvitedGroupsFinder) do |finder|
          allow(finder).to receive(:execute).and_raise(ActiveRecord::RecordNotFound)
        end

        get(:project_groups, params: { project_id: project.id })

        expect(response).to be_not_found
      end
    end
  end

  describe 'GET group_subgroups', feature_category: :groups_and_projects do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:subgroup_1) { create(:group, :private, parent: group) }
    let_it_be(:subgroup_2) { create(:group, :private, parent: group) }
    let_it_be(:grandchild_1) { create(:group, :private, parent: subgroup_1) }
    let_it_be(:member_in_group) { create(:user, reporter_of: group) }
    let_it_be(:member_in_subgroup) { create(:user, reporter_of: subgroup_1) }

    let(:params) { { group_id: group.id } }
    let(:current_user) { member_in_group }

    before do
      sign_in(current_user)
    end

    subject { get :group_subgroups, params: params }

    it 'returns subgroups', :aggregate_failures do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(group_names_in_json_response).to contain_exactly(subgroup_1.name, subgroup_2.name)
    end

    context 'when requesting to subgroup 1' do
      let(:params) { { group_id: subgroup_1.id } }

      it 'returns grandchild', :aggregate_failures do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(group_names_in_json_response).to contain_exactly(grandchild_1.name)
      end
    end

    context 'when requesting to subgroup 2' do
      let(:params) { { group_id: subgroup_2.id } }

      it 'returns empty', :aggregate_failures do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(group_names_in_json_response).to be_empty
      end
    end

    context 'when user does not have an access to the group' do
      let(:current_user) { member_in_subgroup }

      it 'returns not found' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    def group_names_in_json_response
      json_response.map { |res| res['name'] }
    end
  end

  shared_examples 'has expected results' do
    it 'returns the matching routes', :aggregate_failures do
      expect(json_response).to be_kind_of(Array)
      expect(json_response.size).to eq(expected_results.length)

      json_response.each do |result|
        expect(expected_results).to include(result.values_at('source_id', 'source_type'))
      end
    end
  end

  context 'GET project_routes', feature_category: :groups_and_projects do
    let_it_be(:group) { create(:group) }
    let_it_be(:projects) { create_list(:project, 3, group: group) }

    before do
      sign_in(user)
      get(:project_routes, params: { search: search })
    end

    context 'as admin' do
      let_it_be(:user) { create(:admin) }

      shared_examples 'search as admin' do
        describe 'while searching for a project by namespace' do
          let(:search) { group.path }
          let!(:expected_results) { group.projects.map { |p| [p.id, 'Project'] } }

          include_examples 'has expected results'
        end

        describe 'while searching for a project by path' do
          let(:search) { projects.first.path }
          let!(:expected_results) { [[projects.first.id, 'Project']] }

          include_examples 'has expected results'
        end
      end

      context 'when admin mode setting is disabled', :do_not_mock_admin_mode_setting do
        it_behaves_like 'search as admin'
      end

      context 'when admin mode setting is enabled' do
        context 'when in admin mode', :enable_admin_mode do
          it_behaves_like 'search as admin'
        end

        context 'when not in admin mode' do
          let(:search) { projects.first.path }
          let!(:expected_results) { [] }

          include_examples 'has expected results'
        end
      end
    end

    context 'as project owner' do
      let(:user) { project.first_owner }
      let!(:expected_results) { [[project.id, 'Project']] }

      context "while searching for a project by namespace" do
        let(:search) { user.namespace.path }

        include_examples 'has expected results'
      end

      context "while searching for a project by path" do
        let(:search) { project.path }

        include_examples 'has expected results'
      end
    end

    context 'while searching for nothing' do
      let(:search) { nil }
      let(:expected_results) { [] }

      include_examples 'has expected results'
    end
  end

  context 'GET namespace_routes', feature_category: :groups_and_projects do
    let_it_be(:groups) { create_list(:group, 3, :private) }
    let_it_be(:users) { create_list(:user, 3) }

    before do
      sign_in(user)
      get(:namespace_routes, params: { search: search })
    end

    context 'as admin' do
      let_it_be(:user) { create(:admin) }

      shared_examples 'search as admin' do
        describe 'while searching for a namespace by group path' do
          let(:search) { 'group' }
          let!(:expected_results) do
            Group.all.map { |g| [g.id, 'Namespace'] }
          end

          include_examples 'has expected results'
        end

        describe 'while searching for a namespace by user path' do
          let(:search) { 'user' }
          let!(:expected_results) do
            User.all.map { |u| [u.namespace.id, 'Namespace'] }
          end

          include_examples 'has expected results'
        end
      end

      context 'when admin mode setting is disabled', :do_not_mock_admin_mode_setting do
        it_behaves_like 'search as admin'
      end

      context 'when admin mode setting is enabled' do
        context 'when in admin mode', :enable_admin_mode do
          it_behaves_like 'search as admin'
        end

        context 'when not in admin mode' do
          let(:search) { 'group' }
          let!(:expected_results) { [] }

          include_examples 'has expected results'
        end
      end
    end

    context 'as a user' do
      let(:search) { user.namespace.path }

      context "while searching for a namespace by path" do
        let!(:expected_results) { [[user.namespace.id, 'Namespace']] }

        include_examples 'has expected results'
      end
    end

    context 'as group member' do
      let_it_be(:group_developer) do
        groups.first.add_developer(users.first)

        users.first
      end

      let(:search) { groups.first.path }
      let(:user) { group_developer }

      context "while searching for a namespace by path" do
        let!(:expected_results) { [[groups.first.id, 'Namespace']] }

        include_examples 'has expected results'
      end
    end

    context 'while searching for nothing' do
      let(:search) { nil }
      let(:expected_results) { [] }

      include_examples 'has expected results'
    end
  end
end
