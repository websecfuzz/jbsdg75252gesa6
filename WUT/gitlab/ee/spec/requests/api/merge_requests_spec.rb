# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::MergeRequests, feature_category: :code_review_workflow do
  include ProjectForksHelper

  let_it_be(:user)       { create(:user) }
  let_it_be(:user2)      { create(:user) }
  let_it_be(:project)    { create(:project, :public, :repository, creator: user, namespace: user.namespace, only_allow_merge_if_pipeline_succeeds: false, reporters: user) }
  let_it_be(:milestone)  { create(:milestone, title: '1.0.0', project: project) }
  let_it_be(:milestone1) { create(:milestone, title: '0.9', project: project) }
  let_it_be(:label)      { create(:label, title: 'label', color: '#FFAABB', project: project) }
  let_it_be(:label2)     { create(:label, title: 'a-test', color: '#FFFFFF', project: project) }

  let(:base_time)        { Time.now }
  let!(:merge_request)   { create(:merge_request, :simple, milestone: milestone1, author: user, assignees: [user, user2], source_project: project, target_project: project, title: "Test", created_at: base_time) }

  shared_examples_for 'avoids N+1 queries' do
    specify do
      control = ActiveRecord::QueryRecorder.new { get api(endpoint_path), params: params }

      create_additional_resources

      # An extra 2 queries get executed for the diff committers, the preloading
      # of this will be done separately
      expect { get api(endpoint_path), params: params }.not_to exceed_query_limit(control).with_threshold(2)
    end
  end

  shared_examples_for 'list merge requests API endpoint with approval rules' do
    let_it_be(:user) { project.owner }
    let_it_be(:users) { create_list(:user, 2) }
    let_it_be(:groups) { create_list(:group, 2) }

    let_it_be(:merge_request) do
      create(
        :merge_request,
        source_project: project,
        source_branch: 'source-branch-1'
      )
    end

    let_it_be(:protected_branches) { create_list(:protected_branch, 2, project: project) }

    let_it_be(:approval_project_rule_1) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups
      )
    end

    let_it_be(:approval_project_rule_2) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups
      )
    end

    let_it_be(:approval_project_rule_3) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups,
        protected_branches: protected_branches
      )
    end

    let_it_be(:approval_project_rule_4) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups,
        protected_branches: protected_branches
      )
    end

    before_all do
      users.each do |user|
        project.add_maintainer(user)
      end

      groups.each do |group|
        users = create_list(:user, 2)

        group.add_members(users, GroupMember::MAINTAINER)
      end

      setup_approval_rules(merge_request)
    end

    before do
      stub_licensed_features(merge_request_approvers: true, multiple_approval_rules: true)
    end

    shared_examples_for 'avoids N+1 queries related to approval rules' do
      it_behaves_like 'avoids N+1 queries' do
        let(:create_additional_resources) do
          mr_1 = create(
            :merge_request,
            source_project: project,
            source_branch: 'source-branch-2'
          )

          create(
            :merge_request,
            source_project: project,
            source_branch: 'source-branch-3'
          )

          mr_3 = create(
            :merge_request,
            source_project: project
          )

          setup_approval_rules(mr_1)
          setup_approval_rules(mr_3)

          # Simulate a merged MR
          mr_3.mark_as_merged!
        end
      end
    end

    context 'when overriding approvers is disabled' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it_behaves_like 'avoids N+1 queries related to approval rules'
    end

    context 'when overriding approvers is enabled' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: false)
      end

      it_behaves_like 'avoids N+1 queries related to approval rules'
    end

    def setup_approval_rules(merge_request)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_1, users: users, groups: groups)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_2, users: users, groups: groups)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_3, users: users, groups: groups)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_4, users: users, groups: groups)
      create(:any_approver_rule, merge_request: merge_request)
      create(:code_owner_rule, merge_request: merge_request, users: users, groups: groups)
      create(:report_approver_rule, merge_request: merge_request, users: users, groups: groups)

      create(:approval, merge_request: merge_request, user: users.last)
      create(:approval, merge_request: merge_request, user: groups.last.members.last.user)
    end
  end

  describe 'PUT /projects/:id/merge_requests' do
    def update_merge_request(params)
      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user), params: params
    end

    context 'multiple assignees' do
      let(:other_user) { create(:user) }
      let(:params) do
        { assignee_ids: [user.id, other_user.id] }
      end

      before do
        stub_const("Issuable::MAX_NUMBER_OF_ASSIGNEES_OR_REVIEWERS", 2)
      end

      context 'when licensed' do
        before do
          stub_licensed_features(multiple_merge_request_assignees: true)
        end

        it 'creates merge request with multiple assignees' do
          update_merge_request(params)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['assignees'].size).to eq(2)
          expect(json_response['assignees'].first['name']).to eq(user.name)
          expect(json_response['assignees'].second['name']).to eq(other_user.name)
          expect(json_response.dig('assignee', 'name')).to eq(user.name)
        end

        context 'when assignees is over the limit' do
          let(:params) do
            { assignee_ids: [user.id, other_user.id, create(:user).id] }
          end

          it 'does not create merge request with too many assignees' do
            update_merge_request(params)

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']['assignees']).to match_array(["total must be less than or equal to 2"])
          end
        end
      end

      context 'when not licensed' do
        before do
          stub_licensed_features(multiple_merge_request_assignees: false)
        end

        it 'creates merge request with a single assignee' do
          update_merge_request(params)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['assignees'].size).to eq(1)
          expect(json_response['assignees'].first['name']).to eq(user.name)
          expect(json_response.dig('assignee', 'name')).to eq(user.name)
        end
      end
    end

    context 'reviewers over the max limit' do
      let(:user2) { create(:user) }
      let(:user3) { create(:user) }
      let(:params) do
        { reviewer_ids: [user.id, user2.id, user3.id] }
      end

      before do
        stub_const("Issuable::MAX_NUMBER_OF_ASSIGNEES_OR_REVIEWERS", 2)
      end

      context 'when licensed' do
        before do
          stub_licensed_features(multiple_merge_request_reviewers: true)
        end

        it 'does not create merge request with too many reviewers' do
          update_merge_request(params)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']['reviewers']).to match_array(["total must be less than or equal to 2"])
        end
      end

      context 'when not licensed' do
        before do
          stub_licensed_features(multiple_merge_request_reviewers: false)
        end

        it 'creates merge request with a single reviewer' do
          update_merge_request(params)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['reviewers'].size).to eq(1)
          expect(json_response['reviewers'].first['name']).to eq(user.name)
        end
      end
    end

    context 'when updating existing approval rules' do
      let!(:rule) { create(:approval_merge_request_rule, merge_request: merge_request, approvals_required: 1) }

      it 'is successful' do
        update_merge_request(
          title: "New title",
          approval_rules_attributes: [
            { id: rule.id, approvals_required: 2 }
          ]
        )

        expect(response).to have_gitlab_http_status(:ok)

        merge_request.reload

        expect(merge_request.approval_rules.size).to eq(1)
        expect(merge_request.approval_rules.first.approvals_required).to eq(2)
      end
    end
  end

  describe 'POST /projects/:id/create_ci_config' do
    subject(:request) { post api("/projects/#{project.id}/create_ci_config", user) }

    context 'when authorized' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
                           .with(user, :create_merge_request_in, project)
                           .and_return(true)
      end

      it 'returns success response', :aggregate_failures do
        expect { request }.to change { MergeRequest.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
      end

      context 'when create ci config service returns error' do
        let_it_be(:error)  { { status: :error, message: "Something went wrong", http_status: 422 } }

        before do
          allow_next_instance_of(ComplianceManagement::Projects::CreateCiConfigService) do |instance|
            allow(instance).to receive(:execute).and_return(error)
          end
        end

        it 'returns error response', :aggregate_failures do
          request

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to eq(error[:message])
        end
      end
    end

    context 'when unauthorized' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
                            .with(user, :create_merge_request_in, project)
                            .and_return(false)
      end

      it 'does not create merge request', :aggregate_failures do
        expect { request }.not_to change { MergeRequest.count }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "POST /projects/:id/merge_requests" do
    def create_merge_request(args)
      defaults = {
        title: 'Test merge_request',
        source_branch: 'feature_conflict',
        target_branch: 'master',
        author: user,
        labels: 'label, label2',
        milestone_id: milestone.id
      }
      defaults = defaults.merge(args)
      post api("/projects/#{project.id}/merge_requests", user), params: defaults
    end

    context 'reviewers over the max limit' do
      let(:user2) { create(:user) }
      let(:user3) { create(:user) }
      let(:params) do
        { reviewer_ids: [user.id, user2.id, user3.id] }
      end

      before do
        stub_const("Issuable::MAX_NUMBER_OF_ASSIGNEES_OR_REVIEWERS", 2)
      end

      context 'when licensed' do
        before do
          stub_licensed_features(multiple_merge_request_reviewers: true)
        end

        it 'does not create merge request with too many reviewers' do
          create_merge_request(params)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']['reviewers']).to match_array(["total must be less than or equal to 2"])
        end
      end

      context 'when not licensed' do
        before do
          stub_licensed_features(multiple_merge_request_reviewers: false)
        end

        it 'creates merge request with a single reviewer' do
          create_merge_request(params)

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['reviewers'].size).to eq(1)
          expect(json_response['reviewers'].first['name']).to eq(user.name)
        end
      end
    end

    context 'multiple assignees' do
      context 'when licensed' do
        before do
          stub_licensed_features(multiple_merge_request_assignees: true)
        end

        it 'creates merge request with multiple assignees' do
          create_merge_request(assignee_ids: [user.id, user2.id])

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['assignees'].pluck('name')).to match_array([user.name, user2.name])
          # "main" assignee is selected randomly from the assignees list
          expect(json_response.dig('assignee', 'name')).to be_in([user.name, user2.name])
        end
      end

      context 'when not licensed' do
        before do
          stub_licensed_features(multiple_merge_request_assignees: false)
        end

        it 'creates merge request with a single assignee' do
          create_merge_request(assignee_ids: [user.id, user2.id])

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['assignees'].size).to eq(1)
          expect(json_response['assignees'].first['name']).to eq(user.name)
          expect(json_response.dig('assignee', 'name')).to eq(user.name)
        end
      end
    end

    context 'between branches projects' do
      it "returns merge_request" do
        create_merge_request(squash: true)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['title']).to eq('Test merge_request')
        expect(json_response['labels']).to eq(%w[label label2])
        expect(json_response['milestone']['id']).to eq(milestone.id)
        expect(json_response['squash']).to be_truthy
        expect(json_response['force_remove_source_branch']).to be_falsy
      end

      context 'the approvals_before_merge param' do
        context 'when the target project has disable_overriding_approvers_per_merge_request set to true' do
          before do
            project.update!(disable_overriding_approvers_per_merge_request: true)
            create_merge_request(approvals_before_merge: 1)
          end

          it 'does not set approvals_before_merge' do
            expect(json_response['approvals_before_merge']).to eq(nil)
          end
        end

        context 'when the target project has disable_overriding_approvers_per_merge_request set to false' do
          before do
            project.update!(approvals_before_merge: 0)
            create_merge_request(approvals_before_merge: 1)
          end

          it 'sets approvals_before_merge' do
            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['message']).to eq(nil)
            expect(json_response['approvals_before_merge']).to eq(1)
          end
        end
      end
    end

    context 'when the project has approval rules' do
      let(:project_approvers) { create_list(:user, 3) }
      let!(:any_approver_rule) { create(:approval_project_rule, :any_approver_rule, project: project, approvals_required: 1) }
      let!(:regular_rule) { create(:approval_project_rule, project: project, users: project_approvers, approvals_required: 3) }

      before do
        project_approvers.each { |u| project.add_developer(u) }
      end

      it 'inherits project-level approval rules' do
        create_merge_request({})

        expect(response).to have_gitlab_http_status(:created)

        merge_request = MergeRequest.find(json_response['id'])

        merge_request_approval_rules = merge_request.approval_rules.map(&:attributes)

        expect(merge_request_approval_rules.count).to eq(2)
        expect(merge_request_approval_rules).to include(a_hash_including('name' => any_approver_rule.name, 'rule_type' => 'any_approver', 'approvals_required' => 1))
        expect(merge_request_approval_rules).to include(a_hash_including('name' => regular_rule.name, 'rule_type' => 'regular', 'approvals_required' => 3))

        expect(merge_request.approval_rules.map(&:user_ids)).to match_array([[], project_approvers.map(&:id)])
      end
    end
  end

  describe 'PUT /projects/:id/merge_requests/:merge_request_iid/merge' do
    it 'returns 405 if merge request was not approved' do
      project.add_developer(create(:user))
      project.update!(approvals_before_merge: 1)

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)

      expect(response).to have_gitlab_http_status(:method_not_allowed)
    end

    it 'returns 200 if merge request was approved' do
      approver = create(:user)
      project.add_developer(approver)
      project.update!(approvals_before_merge: 1)
      merge_request.approvals.create!(user: approver)

      put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user)

      expect(response).to have_gitlab_http_status(:ok)
    end

    context 'when the requests asks to skip the train', :aggregate_failures do
      let(:project)       { create(:project, :public, :repository, creator: user, namespace: user.namespace) }
      let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let(:skip_params)   { { skip_merge_train: true } }

      let(:request) do
        put api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/merge", user), params: skip_params
      end

      before do
        stub_licensed_features(merge_pipelines: true, merge_trains: true)

        project.update!(approvals_before_merge: 0)
        project.ci_cd_settings.update!(
          merge_pipelines_enabled: true,
          merge_trains_enabled: true,
          merge_trains_skip_train_allowed: true
        )
      end

      it 'creates a new merged train car to represent the merged MR' do
        expect { request }.to change { MergeTrains::Car.count }.by(1)

        expect(response).to have_gitlab_http_status(:ok)
        expect(merge_request.reload).to be_merged
      end

      context 'with merge_trains_skip_train disabled' do
        before do
          stub_feature_flags(merge_trains_skip_train: false)
        end

        it 'creates a new merged train car to represent the merged MR' do
          expect { request }.not_to change { MergeTrains::Car.count }

          expect(response).to have_gitlab_http_status(:ok)
          expect(merge_request.reload).to be_merged
        end
      end
    end
  end

  describe "DELETE /projects/:id/merge_requests/:merge_request_iid" do
    context "when the merge request is on the merge train" do
      let!(:merge_request) { create(:merge_request, :on_train, source_project: project, target_project: project) }

      before do
        ::MergeRequests::MergeToRefService.new(project: merge_request.project, current_user: merge_request.merge_user, params: { target_ref: merge_request.train_ref_path })
                                          .execute(merge_request)
      end

      it 'removes train ref' do
        expect do
          delete api("/projects/#{project.id}/merge_requests/#{merge_request.iid}", user)
        end.to change { project.repository.ref_exists?(merge_request.train_ref_path) }.from(true).to(false)
      end
    end
  end

  context 'when authenticated' do
    context 'filter merge requests by assignee ID' do
      let!(:merge_request2) do
        create(:merge_request, :simple, assignees: [user2], source_project: project, target_project: project, source_branch: 'other-branch-2')
      end

      it 'returns merge requests with given assignee ID' do
        get api('/merge_requests', user), params: { assignee_id: user2.id }

        expect_response_contain_exactly(merge_request2.id, merge_request.id)
      end
    end

    context 'filter merge requests by approver IDs' do
      let!(:merge_request_with_approver) do
        create(:merge_request_with_approver, :simple, author: user, source_project: project, target_project: project, source_branch: 'other-branch')
      end

      before do
        get api('/merge_requests', user), params: { approver_ids: approvers_param, scope: :all }
      end

      context 'with specified approver id' do
        let(:approvers_param) { [merge_request_with_approver.approvers.first.user_id] }

        it 'returns an array of merge requests which have specified the user as an approver' do
          expect_response_contain_exactly(merge_request_with_approver.id)
        end
      end

      context 'with specified None as a param' do
        let(:approvers_param) { 'None' }

        it 'returns an array of merge requests with no approvers' do
          expect_response_contain_exactly(merge_request.id)
        end
      end

      context 'with specified Any as a param' do
        let(:approvers_param) { 'Any' }

        it 'returns an array of merge requests with any approver' do
          expect_response_contain_exactly(merge_request_with_approver.id)
        end
      end

      context 'with any other string as a param' do
        let(:approvers_param) { 'any-other-string' }

        it 'returns a validation error' do
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eq("approver_ids should be an array, 'None' or 'Any'")
        end
      end
    end

    shared_examples 'filter merge requests by approved_by_x' do
      let_it_be(:user3) { create(:user) }
      let_it_be(:merge_request_with_approval) do
        create(:merge_request, author: user, source_project: project, target_project: project, source_branch: 'other-branch').tap do |mr|
          create(:approval, merge_request: mr, user: user2)
        end
      end

      let_it_be(:merge_request_with_multiple_approvals) do
        create(:merge_request, author: user, source_project: project, target_project: project, source_branch: 'another-branch').tap do |mr|
          create(:approval, merge_request: mr, user: user2)
          create(:approval, merge_request: mr, user: user3)
        end
      end

      before do
        get api('/merge_requests', user), params: params
      end

      context 'with specified approved_by param' do
        let(:approvals_param) { [user_attribute.call(user2)] }

        it 'returns an array of merge requests which have specified the user as an approver' do
          expect_response_contain_exactly(merge_request_with_approval.id, merge_request_with_multiple_approvals.id)
        end
      end

      context 'with multiple specified approved_by params' do
        context 'when approved by all users' do
          let(:approvals_param) { [user_attribute.call(user2), user_attribute.call(user3)] }

          it 'returns an array of merge requests which have specified the user as an approver' do
            expect_response_contain_exactly(merge_request_with_multiple_approvals.id)
          end
        end

        context 'when not approved by all users' do
          let(:approvals_param) { [user_attribute.call(user), user_attribute.call(user2)] }

          it 'does not return any merge request' do
            expect_empty_array_response
          end
        end
      end

      context 'with specified None as a param' do
        let(:approvals_param) { 'None' }

        it 'returns an array of merge requests with no approvers' do
          expect_response_contain_exactly(merge_request.id)
        end
      end

      context 'with specified Any as a param' do
        let(:approvals_param) { 'Any' }

        it 'returns an array of merge requests with any approver' do
          expect_response_contain_exactly(merge_request_with_approval.id, merge_request_with_multiple_approvals.id)
        end
      end

      context 'with any other string as a param' do
        let(:approvals_param) { 'any-other-string' }

        it 'returns a validation error' do
          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']).to eq(error)
        end
      end
    end

    context 'filter merge requests by approved_by_ids' do
      let(:params) { { approved_by_ids: approvals_param, scope: :all } }
      let(:error) { "approved_by_ids should be an array, 'None' or 'Any'" }
      let(:user_attribute) { ->(user) { user.id } }

      it_behaves_like 'filter merge requests by approved_by_x'
    end

    context 'filter merge requests by approved_by_usernames' do
      let(:params) { { approved_by_usernames: approvals_param, scope: :all } }
      let(:error) { "approved_by_usernames should be an array, 'None' or 'Any'" }
      let(:user_attribute) { ->(user) { user.username } }

      it_behaves_like 'filter merge requests by approved_by_x'
    end
  end

  describe 'GET /projects/:id/merge_requests' do
    let(:endpoint_path) { "/projects/#{project.id}/merge_requests" }
    let(:params) { { with_labels_details: true } } # With this param we skip caching the response
    let(:another_mr) { create(:merge_request, source_project: project, target_project: project, target_branch: 'feature') }

    it_behaves_like 'list merge requests API endpoint with approval rules'

    context 'with protected branch squash option' do
      before do
        stub_licensed_features(branch_rule_squash_options: true)

        protected_branch = create(:protected_branch, name: merge_request.target_branch, project_id: project.id)
        create(:branch_rule_squash_option, squash_option: 'always', protected_branch: protected_branch, project: project)
      end

      it 'does not have N+1 issues' do
        get api(endpoint_path), params: params # Warmup the cache for the mergability checks

        control = ActiveRecord::QueryRecorder.new { get api(endpoint_path), params: params }

        protected_branch = create(:protected_branch, name: another_mr.target_branch, project_id: project.id)
        create(:branch_rule_squash_option, squash_option: 'always', protected_branch: protected_branch, project: project)

        # An extra query for LFS file locks happens due to the order of the merge checks
        expect { get api(endpoint_path), params: params }.not_to exceed_query_limit(control).with_threshold(1)
      end
    end

    context 'when multiple MRs have requested changes' do
      before do
        stub_licensed_features(requested_changes_block_merge_request: true)
        create(:merge_request_requested_changes, merge_request: merge_request, project: project)
      end

      it 'does not have N+1 issues' do
        control = ActiveRecord::QueryRecorder.new { get api(endpoint_path), params: params }

        create(:merge_request_requested_changes, merge_request: another_mr, project: project)

        expect { get api(endpoint_path), params: params }.not_to exceed_query_limit(control)
      end
    end
  end
end
