# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::IssuesController, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:user) { issue.author }
  let_it_be(:blocking_issue) { create(:issue, project: project) }
  let_it_be(:blocked_by_issue) { create(:issue, project: project) }

  before do
    login_as(user)
  end

  describe 'GET #show' do
    def get_show
      allow(Gitlab::QueryLimiting::Transaction).to receive(:threshold).and_return(102)
      get project_issue_path(project, issue)
    end

    context 'with blocking issues' do
      before do
        get_show # Warm the cache
      end

      it 'does not cause extra queries when multiple blocking issues are present' do
        create(:issue_link, source: blocking_issue, target: issue, link_type: IssueLink::TYPE_BLOCKS)

        project.reload
        control = ActiveRecord::QueryRecorder.new { get_show }

        other_project_issue = create(:issue)
        other_project_issue.project.add_developer(user)
        create(:issue_link, source: other_project_issue, target: issue, link_type: IssueLink::TYPE_BLOCKS)

        expect { get_show }.not_to exceed_query_limit(control)
      end
    end

    context 'with test case' do
      before do
        project.add_guest(user)
      end

      it 'redirects to test cases show' do
        test_case = create(:quality_test_case, project: project)

        get project_issue_path(project, test_case)

        expect(response).to redirect_to(project_quality_test_case_path(project, test_case))
      end
    end

    it_behaves_like 'seat count alert' do
      subject { get_show }

      let(:namespace) { project }

      before do
        project.add_developer(user)
      end
    end

    it 'exposes the escalation_policies licensed feature setting' do
      project.add_guest(user)
      stub_licensed_features(escalation_policies: true)

      get_show

      expect(response.body).to have_pushed_frontend_feature_flags(escalationPolicies: true)
    end

    context 'for summarize notes feature' do
      context 'when user is a member' do
        before do
          project.add_guest(user)

          allow(Ability).to receive(:allowed?).and_call_original
        end

        context 'when feature is available' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :summarize_comments, issue).and_return(true)
            stub_licensed_features(summarize_comments: true)
          end

          it 'exposes the required feature flags' do
            get_show

            expect(response.body).to have_pushed_licensed_features(summarizeComments: true)
          end
        end

        context 'when feature is not available' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :summarize_comments, issue).and_return(false)
          end

          it 'does not push licensed feature' do
            get_show

            expect(response.body).not_to have_pushed_licensed_features(summarizeComments: true)
          end
        end
      end

      context 'when user is not a member' do
        before do
          stub_licensed_features(summarize_comments: true)
        end

        it 'does not push licensed feature' do
          get_show

          expect(response.body).not_to have_pushed_licensed_features(summarizeComments: true)
        end
      end
    end
  end

  describe 'GET #index' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:project) { create(:project, group: group, developers: [user]) }
    let_it_be(:issues) { create_list(:issue, 5, project: project, due_date: Date.current) }
    let(:params) { {} }

    subject(:get_index) { get project_issues_path(project, params: params) }

    context 'when work_item_planning_view is disabled' do
      before do
        stub_feature_flags(work_item_planning_view: false)
      end

      context 'when viewing all issues' do
        include_examples 'seat count alert' do
          let(:namespace) { project }

          before do
            project.add_developer(user)
          end
        end
      end

      context 'when filtering by custom field' do
        include_context 'with group configured with custom fields'

        before_all do
          create(:work_item_select_field_value, work_item_id: issues[0].id, custom_field: select_field,
            custom_field_select_option: select_option_1)
          create(:work_item_select_field_value, work_item_id: issues[1].id, custom_field: select_field,
            custom_field_select_option: select_option_2)
          create(:work_item_select_field_value, work_item_id: issues[2].id, custom_field: select_field,
            custom_field_select_option: select_option_2)
        end

        before do
          stub_licensed_features(custom_fields: true)
        end

        context 'when requesting RSS feed' do
          it 'returns issues filtered by the custom field value' do
            get project_issues_path(project, format: :atom, custom_field: { select_field.id => select_option_2.id })

            expect(response).to have_gitlab_http_status(:ok)

            issue_titles = Nokogiri::XML(response.body).css('feed entry title').map(&:text)
            expect(issue_titles).to contain_exactly(issues[1].title, issues[2].title)
          end
        end

        context 'when requesting calendar feed' do
          it 'returns issues filtered by the custom field value' do
            get project_issues_path(project, format: :ics, custom_field: { select_field.id => select_option_2.id })

            expect(response).to have_gitlab_http_status(:ok)

            event_titles = response.body.split("\r\n").filter { |s| s.start_with?('SUMMARY:') }
            expect(event_titles).to contain_exactly(
              "SUMMARY:#{issues[1].title} (in #{project.full_path})",
              "SUMMARY:#{issues[2].title} (in #{project.full_path})"
            )
          end
        end
      end
    end
  end
end
