# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::MergeRequestsController, feature_category: :code_review_workflow do
  include ReactiveCachingHelpers

  let(:merge_request) { create(:merge_request) }
  let(:project) { merge_request.project }
  let(:user) { merge_request.author }

  before do
    login_as(user)
  end

  describe 'GET #show' do
    def get_show
      get project_merge_request_path(project, merge_request)
    end

    context "when resolveVulnerabilityWithAi ability is allowed" do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :resolve_vulnerability_with_ai, project).and_return(true)

        get_show
      end

      it 'sets the frontend ability to true' do
        expect(response.body).to have_pushed_frontend_ability(resolveVulnerabilityWithAi: true)
      end
    end

    context "when resolveVulnerabilityWithAi ability is not allowed" do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :resolve_vulnerability_with_ai, project).and_return(false)

        get_show
      end

      it 'sets the frontend ability to false' do
        expect(response.body).to have_pushed_frontend_ability(resolveVulnerabilityWithAi: false)
      end
    end

    context "when the merge request is publicly accessible" do
      let_it_be(:public_project) { create(:project, :public) }
      let_it_be(:public_merge_request) { create(:merge_request, source_project: public_project) }

      def get_public_show
        get project_merge_request_path(public_project, public_merge_request)
      end

      context "with AI features available" do
        before do
          authorizer = instance_double(::Gitlab::Llm::FeatureAuthorizer)
          allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(authorizer)
          allow(authorizer).to receive(:allowed?).and_return(true)

          service = instance_double(CloudConnector::BaseAvailableServiceData)
          allow(::CloudConnector::AvailableServices).to receive(:find_by_name).and_return(service)
          allow(service).to receive_messages({ free_access?: true })
          allow(::Gitlab::Saas).to receive(:feature_available?).and_return(true)
        end

        context "when the user is logged out" do
          before do
            sign_out(user)
            get_public_show
          end

          it 'sets the frontend ability to false' do
            expect(response.body).to have_pushed_frontend_ability(resolveVulnerabilityWithAi: false)
          end
        end
      end
    end
  end

  describe 'GET #edit' do
    def get_edit
      get edit_project_merge_request_path(project, merge_request)
    end

    context 'when the project requires code owner approval' do
      before do
        stub_licensed_features(code_owners: true, code_owner_approval_required: true)

        get_edit # Warm the cache
      end

      it 'does not cause an extra queries when code owner rules are present' do
        control = ActiveRecord::QueryRecorder.new { get_edit }

        create(:code_owner_rule, merge_request: merge_request)

        # Threshold of 3 because we load the source_rule, users & group users for all rules
        expect { get_edit }.not_to exceed_query_limit(control).with_threshold(3)
      end

      it 'does not cause extra queries when multiple code owner rules are present' do
        create(:code_owner_rule, merge_request: merge_request)

        control = ActiveRecord::QueryRecorder.new { get_edit }

        create(:code_owner_rule, merge_request: merge_request)

        expect { get_edit }.not_to exceed_query_limit(control)
      end
    end
  end

  describe 'GET #index' do
    def get_index
      get project_merge_requests_path(project, state: 'opened')
    end

    # TODO: Fix N+1 and do not skip this spec: https://gitlab.com/gitlab-org/gitlab/-/issues/424342
    # See: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/131006
    xit 'avoids N+1' do
      other_user = create(:user)
      create(:merge_request, :unique_branches, target_project: project, source_project: project)
      create_list(:approval_project_rule, 5, project: project, users: [user, other_user], approvals_required: 2)
      create_list(:approval_merge_request_rule, 5, merge_request: merge_request, users: [user, other_user], approvals_required: 2)

      control = ActiveRecord::QueryRecorder.new { get_index }

      create_list(:approval, 10)
      create(:approval_project_rule, project: project, users: [user, other_user], approvals_required: 2)
      create_list(:merge_request, 20, :unique_branches, target_project: project, source_project: project).each do |mr|
        create(:approval_merge_request_rule, merge_request: mr, users: [user, other_user], approvals_required: 2)
      end

      expect { get_index }.not_to exceed_query_limit(control)
    end
  end

  describe 'security_reports' do
    let_it_be(:merge_request) { create(:merge_request, :with_head_pipeline) }
    let_it_be(:user) { create(:user) }

    subject(:request_report) { get security_reports_project_merge_request_path(project, merge_request, type: :sast, format: :json) }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the user can not read project security resources' do
      before do
        project.add_guest(user)
      end

      it 'responds with 404' do
        request_report

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the user can read project security resources' do
      before do
        project.add_developer(user)
      end

      context 'when the pipeline is pending' do
        it 'returns 204 HTTP status along with the `Poll-Interval` header' do
          request_report

          expect(response).to have_gitlab_http_status(:no_content)
          expect(response.headers['Poll-Interval']).to eq('3000')
        end
      end

      context 'when the pipeline is not pending' do
        before do
          merge_request.head_pipeline.reload.succeed!
        end

        context 'when the given type is invalid' do
          let(:error) { ::Security::MergeRequestSecurityReportGenerationService::InvalidReportTypeError }

          before do
            allow(::Security::MergeRequestSecurityReportGenerationService).to receive(:execute).and_raise(error)
          end

          it 'responds with 400' do
            request_report

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(response.header).not_to include('Poll-Interval')
          end
        end

        context 'when the given type is valid' do
          before do
            allow(::Security::MergeRequestSecurityReportGenerationService)
              .to receive(:execute).with(an_instance_of(MergeRequest), 'sast').and_return(report_payload)
          end

          context 'when comparison is being processed' do
            let(:report_payload) { { status: :parsing } }

            it 'returns 204 HTTP status along with the `Poll-Interval` header' do
              request_report

              expect(response).to have_gitlab_http_status(:no_content)
              expect(response.headers['Poll-Interval']).to eq('3000')
            end
          end

          context 'when comparison is done' do
            context 'when the comparison is errored' do
              let(:report_payload) { { status: :error } }

              it 'responds with 400' do
                request_report

                expect(response).to have_gitlab_http_status(:bad_request)
                expect(response.header).not_to include('Poll-Interval')
              end
            end

            context 'when the comparision is succeeded' do
              let(:report_payload) { { status: :parsed, data: { added: ['foo'], fixed: ['bar'] } } }

              it 'responds with 200 along with the report payload' do
                request_report

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response).to eq({ 'added' => ['foo'], 'fixed' => ['bar'] })
              end
            end
          end
        end
      end
    end
  end

  describe 'GET #license_scanning_reports_collapsed', feature_category: :code_review_workflow do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:merge_request) { create(:ee_merge_request, :with_cyclonedx_reports, source_project: project) }

    subject(:request_license_scanning_reports) { get license_scanning_reports_collapsed_project_merge_request_path(project, merge_request, format: :json) }

    before do
      stub_licensed_features(license_scanning: true)
    end

    context 'when comparison is done' do
      context 'with license_scanning report in head pipeline' do
        before do
          allow_next_found_instance_of(MergeRequest) { |merge_request| synchronous_reactive_cache(merge_request) }
        end

        let(:expected_response) { { 'approval_required' => false, 'existing_licenses' => 0, 'has_denied_licenses' => false, 'new_licenses' => 1, 'removed_licenses' => 0 } }

        let(:head_pipeline) do
          create(
            :ee_ci_pipeline,
            :with_license_scanning_feature_branch,
            project: project,
            ref: merge_request.source_branch,
            sha: merge_request.diff_head_sha
          )
        end

        let(:base_pipeline) do
          create(
            :ee_ci_pipeline,
            project: project,
            ref: merge_request.target_branch,
            sha: merge_request.diff_base_sha
          )
        end

        it 'does not send polling interval' do
          expect(::Gitlab::PollingInterval).not_to receive(:set_header)

          request_license_scanning_reports
        end

        it 'returns 200 HTTP status' do
          request_license_scanning_reports

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq(expected_response)
        end

        context 'without license_scanning report in base pipeline' do
          context 'when the base pipeline is nil' do
            let!(:base_pipeline) { nil }

            it 'returns 200 HTTP status' do
              request_license_scanning_reports

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).to eq(expected_response)
            end
          end

          context 'when the base pipeline does not have license reports' do
            it 'returns 200 HTTP status' do
              request_license_scanning_reports

              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).to eq(expected_response)
            end
          end
        end
      end
    end
  end

  describe 'GET #reports' do
    before do
      get reports_project_merge_request_path(project, merge_request)
    end

    context 'when feature flag is disabled' do
      before_all do
        stub_feature_flags(mr_reports_tab: false)
      end

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end

    it { expect(response).to have_gitlab_http_status(:ok) }
  end

  describe 'PUT #update' do
    subject(:send_request) do
      put project_merge_request_path(project, merge_request), params: {
        merge_request: { description: description }
      }
    end

    include_examples 'handle quickactions without Duo access'
  end
end
