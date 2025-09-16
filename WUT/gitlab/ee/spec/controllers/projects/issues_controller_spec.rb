# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::IssuesController, feature_category: :team_planning do
  let_it_be(:namespace, reload: true) { create(:group, :public) }
  let_it_be(:project, reload: true) { create(:project_empty_repo, :public, namespace: namespace) }
  let_it_be(:user, reload: true) { create(:user) }

  describe 'licensed features' do
    let(:project) { create(:project, group: namespace) }
    let(:user) { create(:user) }
    let(:epic) { create(:epic, group: namespace) }
    let(:issue) { create(:issue, project: project, weight: 5) }
    let(:issue2) { create(:issue, project: project, weight: 1) }
    let(:new_issue) { build(:issue, project: project, weight: 5) }

    before do
      namespace.add_developer(user)
      sign_in(user)
    end

    def perform(method, action, opts = {})
      send(method, action, params: opts.merge(namespace_id: project.namespace.to_param, project_id: project.to_param))
    end

    context 'licensed' do
      before do
        stub_licensed_features(issue_weights: true, epics: true, security_dashboard: true, issuable_default_templates: true)
      end

      context 'when user can generate description' do
        before do
          allow(controller).to receive(:push_licensed_feature)
          allow(controller).to receive(:can?).and_call_original
          allow(controller).to receive(:can?).with(anything, :generate_description, anything).and_return(true)
        end

        describe 'generate_description feature' do
          describe 'GET #new' do
            context 'when generate_description is licensed' do
              before do
                stub_licensed_features(generate_description: true)
              end

              it 'pushes generate_description licensed feature' do
                get :new, params: { namespace_id: project.namespace, project_id: project }

                expect(controller).to have_received(:push_licensed_feature).with(:generate_description, project)
              end
            end

            context 'when generate_description is not licensed' do
              before do
                stub_licensed_features(generate_description: false)
              end

              it 'pushes generate_description licensed feature when user has permission regardless of license status' do
                get :new, params: { namespace_id: project.namespace, project_id: project }

                expect(controller).to have_received(:push_licensed_feature).with(:generate_description, project)
              end
            end
          end

          describe 'GET #show' do
            let(:issue) { create(:issue, project: project) }

            context 'when generate_description is licensed' do
              before do
                stub_licensed_features(generate_description: true)
              end

              it 'pushes generate_description licensed feature' do
                get :show, params: { namespace_id: project.namespace, project_id: project, id: issue.iid }

                expect(controller).to have_received(:push_licensed_feature).with(:generate_description, project)
              end
            end

            context 'when generate_description is not licensed' do
              before do
                stub_licensed_features(generate_description: false)
              end

              it 'pushes generate_description licensed feature when user has permission regardless of license status' do
                get :show, params: { namespace_id: project.namespace, project_id: project, id: issue.iid }

                expect(controller).to have_received(:push_licensed_feature).with(:generate_description, project)
              end
            end
          end

          context 'when user cannot generate description' do
            before do
              allow(controller).to receive(:can?).and_call_original
              allow(controller).to receive(:can?).with(user, :generate_description, project).and_return(false)
              stub_licensed_features(generate_description: true)
            end

            describe 'GET #new' do
              it 'does not push generate_description licensed feature' do
                get :new, params: { namespace_id: project.namespace, project_id: project }

                expect(controller).not_to have_received(:push_licensed_feature).with(:generate_description, project)
              end
            end

            describe 'GET #show' do
              let(:issue) { create(:issue, project: project) }

              it 'does not push generate_description licensed feature' do
                get :show, params: { namespace_id: project.namespace, project_id: project, id: issue.iid }

                expect(controller).not_to have_received(:push_licensed_feature).with(:generate_description, project)
              end
            end
          end
        end
      end

      describe '#update' do
        it 'sets issue weight and epic' do
          perform :put, :update, id: issue.to_param, issue: { weight: 6, epic_id: epic.id }, format: :json

          expect(response).to have_gitlab_http_status(:ok)
          expect(issue.reload.weight).to eq(6)
          expect(issue.epic).to eq(epic)
        end
      end

      describe '#new' do
        render_views

        context 'when a vulnerability_id is provided' do
          let(:finding) { create(:vulnerabilities_finding, :with_pipeline) }
          let(:vulnerability) { create(:vulnerability, project: project, findings: [finding]) }
          let(:vulnerability_field) { "<input type=\"hidden\" name=\"vulnerability_id\" id=\"vulnerability_id\" value=\"#{vulnerability.id}\" autocomplete=\"off\" />" }

          subject { get :new, params: { namespace_id: project.namespace, project_id: project, vulnerability_id: vulnerability.id } }

          it 'sets the vulnerability_id' do
            subject

            expect(response.body).to include(vulnerability_field)
          end

          it 'sets the confidential flag to true by default' do
            subject

            expect(assigns(:issue).confidential).to eq(true)
          end
        end

        context 'default templates' do
          let(:selected_field) { 'data-default="Default"' }
          let(:files) { { '.gitlab/issue_templates/Default.md' => '' } }

          subject { get :new, params: { namespace_id: project.namespace, project_id: project } }

          context 'when a template has been set via project settings' do
            let(:project) { create(:project, :custom_repo, namespace: namespace, issues_template: 'Content', files: files) }

            it 'does not select a default template' do
              subject

              expect(response.body).not_to include(selected_field)
            end
          end

          context 'when a template has not been set via project settings' do
            let(:project) { create(:project, :custom_repo, namespace: namespace, files: files) }

            it 'selects a default template' do
              subject

              expect(response.body).to include(selected_field)
            end
          end
        end
      end

      shared_examples 'creates vulnerability issue link' do
        it 'links the issue to the vulnerability' do
          send_request

          expect(project.issues.last.vulnerability_links.first.vulnerability).to eq(vulnerability)
        end

        context 'when vulnerability already has a linked issue' do
          render_views

          let!(:vulnerabilities_issue_link) { create(:vulnerabilities_issue_link, :created, vulnerability: vulnerability) }

          it 'shows an error message' do
            send_request

            expect(flash[:raw]).to include('id="js-unable-to-link-vulnerability"')
            expect(flash[:raw]).to include("data-vulnerability-link=\"/#{namespace.path}/#{project.path}/-/security/vulnerabilities/#{vulnerabilities_issue_link.vulnerability.id}\"")

            expect(vulnerability.issue_links.map(&:issue)).to eq([vulnerabilities_issue_link.issue])
          end
        end
      end

      describe '#create' do
        it 'sets issue weight and epic' do
          perform :post, :create, issue: new_issue.attributes.merge(epic_id: epic.id)

          project_issues = Issue.where.not(project: nil)
          issue = project_issues.first

          expect(response).to have_gitlab_http_status(:found)
          expect(project_issues.count).to eq(1)

          expect(issue.weight).to eq(new_issue.weight)
          expect(issue.epic).to eq(epic)
        end

        context 'when created from a vulnerability' do
          let(:finding) { create(:vulnerabilities_finding, :with_pipeline) }
          let(:vulnerability) { create(:vulnerability, project: project, findings: [finding]) }

          before do
            stub_licensed_features(security_dashboard: true)
            namespace.add_maintainer(user)
          end

          it 'overwrites the default fields' do
            send_request

            issue = project.issues.last
            expect(issue.title).to eq('Title')
            expect(issue.description).to eq('Description')
            expect(issue.confidential).to be false
          end

          it 'does not show an error message' do
            expect(flash[:alert]).to be_nil
          end

          it 'creates vulnerability feedback' do
            send_request

            expect(project.issues.last).to eq(Vulnerabilities::Feedback.last.issue)
          end

          it_behaves_like 'creates vulnerability issue link'

          private

          def send_request
            post :create, params: {
              namespace_id: project.namespace.to_param,
              project_id: project,
              issue: { title: 'Title', description: 'Description', confidential: 'false' },
              vulnerability_id: vulnerability.id
            }
          end
        end
      end
    end

    context 'unlicensed' do
      before do
        stub_licensed_features(issue_weights: false, epics: false, security_dashboard: false)
      end

      describe '#update' do
        it 'does not set issue weight' do
          perform :put, :update, id: issue.to_param, issue: { weight: 6 }, format: :json

          expect(response).to have_gitlab_http_status(:ok)
          expect(issue.reload.weight).to be_nil
          expect(issue.reload.read_attribute(:weight)).to eq(5) # pre-existing data is not overwritten
        end
      end

      describe '#new' do
        render_views

        context 'when a vulnerability_id is provided' do
          let(:finding) { create(:vulnerabilities_finding, :with_pipeline) }
          let(:vulnerability) { create(:vulnerability, project: project, findings: [finding]) }
          let(:vulnerability_field) { "<input type=\"hidden\" name=\"vulnerability_id\" id=\"vulnerability_id\" value=\"#{vulnerability.id}\" />" }

          it 'does not build issue from a vulnerability' do
            get :new, params: { namespace_id: project.namespace, project_id: project, vulnerability_id: vulnerability.id }

            expect(response.body).not_to include(vulnerability_field)
            expect(issue.description).to be_nil
          end
        end
      end

      describe '#create' do
        it 'does not set issue weight ane epic' do
          perform :post, :create, issue: new_issue.attributes

          expect(response).to have_gitlab_http_status(:found)
          expect(Issue.count).to eq(1)

          issue = Issue.first
          expect(issue.weight).to be_nil
          expect(issue.epic).to be_nil
        end
      end
    end
  end

  describe 'GET #show' do
    before do
      project.add_developer(user)
      sign_in(user)
      stub_licensed_features(okrs: true)
    end

    shared_examples 'redirects to show work item page' do
      it 'redirects to work item page using iid' do
        make_request

        expect(response).to redirect_to(project_work_item_path(project, work_item.iid, query))
      end
    end

    context 'when issue is of type objective' do
      let(:query) { {} }

      let_it_be(:work_item) { create(:issue, :objective, project: project) }

      context 'show action' do
        let(:query) { { query: 'any' } }

        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            get :show, params: { namespace_id: project.namespace, project_id: project, id: work_item.iid, **query }
          end
        end
      end

      context 'edit action' do
        let(:query) { { query: 'any' } }

        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            get :edit, params: { namespace_id: project.namespace, project_id: project, id: work_item.iid, **query }
          end
        end
      end

      context 'update action' do
        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            put :update, params: {
              namespace_id: project.namespace,
              project_id: project,
              id: work_item.iid,
              issue: { title: 'New title' }
            }
          end
        end
      end
    end

    context 'when issue is of type key_result' do
      let(:query) { {} }

      let_it_be(:work_item) { create(:issue, :key_result, project: project) }

      context 'show action' do
        let(:query) { { query: 'any' } }

        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            get :show, params: { namespace_id: project.namespace, project_id: project, id: work_item.iid, **query }
          end
        end
      end

      context 'edit action' do
        let(:query) { { query: 'any' } }

        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            get :edit, params: { namespace_id: project.namespace, project_id: project, id: work_item.iid, **query }
          end
        end
      end

      context 'update action' do
        it_behaves_like 'redirects to show work item page' do
          subject(:make_request) do
            put :update, params: {
              namespace_id: project.namespace,
              project_id: project,
              id: work_item.iid,
              issue: { title: 'New title' }
            }
          end
        end
      end
    end
  end

  describe 'GET #new' do
    before do
      project.add_developer(user)
      sign_in(user)
    end

    context 'when passing observability metrics' do
      let(:metric_params) { '%7B%22fullUrl%22%3A%22http%3A%2F%2Fgdk.test%3A3443%2Fflightjs%2FFlight%2F-%2Fmetrics%2Fapp.ads.ad_requests%3Ftype%3DSum%26date_range%3Dcustom%26date_start%3D2024-08-14T16%253A02%253A49.400Z%26date_end%3D2024-08-14T17%253A02%253A49.400Z%22%2C%22name%22%3A%22app.ads.ad_requests%22%2C%22type%22%3A%22Sum%22%2C%22timeframe%22%3A%5B%22Wed%2C%2014%20Aug%202024%2016%3A02%3A49%20GMT%22%2C%22Wed%2C%2014%20Aug%202024%2017%3A02%3A49%20GMT%22%5D%7D' }

      subject do
        get :new, params: {
          namespace_id: project.namespace,
          project_id: project,
          observability_metric_details: metric_params
        }
      end

      context 'when read_observability is prevented' do
        before do
          stub_feature_flags(observability_features: false)
          stub_licensed_features(observability: false)
        end

        context 'when observability_metric_details parameters exist' do
          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end
        end

        context 'when observability_metric_details parameters do not exist' do
          let(:metric_params) { {} }

          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end
        end
      end

      context 'when read_observability is allowed' do
        before do
          stub_licensed_features(observability: true)
        end

        context 'when observability_metric_details parameters exist' do
          it 'does prefill the issue title and description' do
            subject

            expect(assigns(:issue).title).to eq('Issue created from app.ads.ad_requests')
            expect(assigns(:issue).description).to eq(
              <<~TEXT
                [Metric details](http://gdk.test:3443/flightjs/Flight/-/metrics/app.ads.ad_requests?type=Sum&date_range=custom&date_start=2024-08-14T16%3A02%3A49.400Z&date_end=2024-08-14T17%3A02%3A49.400Z) \\
                Name: `app.ads.ad_requests` \\
                Type: `Sum` \\
                Timeframe: `Wed, 14 Aug 2024 16:02:49 GMT - Wed, 14 Aug 2024 17:02:49 GMT`
              TEXT
            )
          end
        end

        context 'when observability_metric_details parameters do not exist' do
          let(:metric_params) { {} }

          it 'does not prefill the issue title and description' do
            subject

            expect(assigns(:issue).title).to be_nil
            expect(assigns(:issue).description).to be_nil
          end
        end
      end
    end

    context 'when passing observability logs' do
      let(:log_params) { '%7B"body"%3A"Consumed%20record%20with%20orderId%3A%200522613b-3a15-11ef-85dd-0242ac120016%2C%20and%20updated%20total%20count%20to%3A%201353"%2C"fingerprint"%3A"8d6c44aebc683e3c"%2C"fullUrl"%3A"http%3A%2F%2Fgdk.test%3A3443%2Fflightjs%2FFlight%2F-%2Flogs%3Fsearch%3D%26service%5B%5D%3Dfrauddetectionservice%26severityNumber%5B%5D%3D9%26traceId%5B%5D%3D72b72def-09b3-e29f-e195-7c6db5ee599f%26fingerprint%5B%5D%3D8d6c44aebc683e3c%26timestamp%3D2024-07-04T14%253A52%253A22.693752628Z%26drawerOpen%3Dtrue"%2C"service"%3A"frauddetectionservice"%2C"severityNumber"%3A9%2C"timestamp"%3A"2024-07-04T14%3A52%3A22.693752628Z"%2C"traceId"%3A"72b72def-09b3-e29f-e195-7c6db5ee599f"%7D' }

      subject do
        get :new, params: {
          namespace_id: project.namespace,
          project_id: project,
          observability_log_details: log_params
        }
      end

      context 'when read_observability is prevented' do
        before do
          stub_feature_flags(observability_features: false)
          stub_licensed_features(observability: false)
        end

        context 'when observability_log_details parameters exist' do
          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            subject

            expect(assigns(:issue).title).to be_nil
            expect(assigns(:issue).description).to be_nil
          end
        end

        context 'when observability_log_details parameters do not exist' do
          let(:log_params) { {} }

          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            subject

            expect(assigns(:issue).title).to be_nil
            expect(assigns(:issue).description).to be_nil
          end
        end
      end

      context 'when read_observability is allowed' do
        before do
          stub_licensed_features(observability: true)
        end

        context 'when observability_log_details parameters exist' do
          it 'does prefill the issue title and description' do
            subject

            expect(assigns(:observability_values)).to eq({
              log: {
                service: 'frauddetectionservice',
                severityNumber: 9,
                fingerprint: '8d6c44aebc683e3c',
                timestamp: '2024-07-04T14:52:22.693752628Z',
                traceId: '72b72def-09b3-e29f-e195-7c6db5ee599f'
              }
            })
            expect(assigns(:issue).title).to eq("Issue created from log of 'frauddetectionservice' service at 2024-07-04T14:52:22.693752628Z")
            expect(assigns(:issue).description).to eq(
              <<~TEXT
                [Log details](http://gdk.test:3443/flightjs/Flight/-/logs?search=&service[]=frauddetectionservice&severityNumber[]=9&traceId[]=72b72def-09b3-e29f-e195-7c6db5ee599f&fingerprint[]=8d6c44aebc683e3c&timestamp=2024-07-04T14%3A52%3A22.693752628Z&drawerOpen=true) \\
                Service: `frauddetectionservice` \\
                Trace ID: `72b72def-09b3-e29f-e195-7c6db5ee599f` \\
                Log Fingerprint: `8d6c44aebc683e3c` \\
                Severity Number: `9` \\
                Timestamp: `2024-07-04T14:52:22.693752628Z` \\
                Message:
                ```
                Consumed record with orderId: 0522613b-3a15-11ef-85dd-0242ac120016, and updated total count to: 1353
                ```
              TEXT
            )
          end
        end

        context 'when observability_log_details parameters do not exist' do
          let(:log_params) { {} }

          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            subject

            expect(assigns(:issue).title).to be_nil
            expect(assigns(:issue).description).to be_nil
          end
        end
      end
    end

    context 'when passing observability tracing' do
      let(:tracing_params) { '%7B%22fullUrl%22%3A%22http%3A%2F%2Fgdk.test%3A3443%2Fflightjs%2FFlight%2F-%2Ftracing%2Fcd4cfff9-295b-f014-595c-1be1fc145822%22%2C%22name%22%3A%22frontend-proxy%20%3A%20ingress%22%2C%22traceId%22%3A%228335ed4c-c943-aeaa-7851-2b9af6c5d3b8%22%2C%22start%22%3A%22Thu%2C%2004%20Jul%202024%2014%3A44%3A21%20GMT%22%2C%22duration%22%3A%222.27ms%22%2C%22totalSpans%22%3A3%2C%22totalErrors%22%3A0%7D' }

      subject do
        get :new, params: {
          namespace_id: project.namespace,
          project_id: project,
          observability_trace_details: tracing_params
        }
      end

      context 'when read_observability is prevented' do
        before do
          stub_feature_flags(observability_features: false)
          stub_licensed_features(observability: false)
        end

        context 'when observability_tracing_details parameters exist' do
          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            subject

            expect(assigns(:issue).title).to be_nil
            expect(assigns(:issue).description).to be_nil
          end
        end

        context 'when observability_tracing_details parameters do not exist' do
          let(:tracing_params) { {} }

          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            subject

            expect(assigns(:issue).title).to be_nil
            expect(assigns(:issue).description).to be_nil
          end
        end
      end

      context 'when read_observability is allowed' do
        before do
          stub_licensed_features(observability: true)
        end

        context 'when observability_tracing_details parameters exist' do
          it 'does prefill the issue title and description' do
            subject

            expect(assigns(:observability_values)).to eq({
              trace: {
                traceId: '8335ed4c-c943-aeaa-7851-2b9af6c5d3b8'
              }
            })
            expect(assigns(:issue).title).to eq("Issue created from trace 'frontend-proxy : ingress'")
            expect(assigns(:issue).description).to eq(
              <<~TEXT
                [Trace details](http://gdk.test:3443/flightjs/Flight/-/tracing/cd4cfff9-295b-f014-595c-1be1fc145822) \\
                Name: `frontend-proxy : ingress` \\
                Trace ID: `8335ed4c-c943-aeaa-7851-2b9af6c5d3b8` \\
                Trace start: `Thu, 04 Jul 2024 14:44:21 GMT` \\
                Duration: `2.27ms` \\
                Total spans: `3` \\
                Total errors: `0`
              TEXT
            )
          end
        end

        context 'when observability_tracing_details parameters do not exist' do
          let(:tracing_params) { {} }

          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            subject

            expect(assigns(:issue).title).to be_nil
            expect(assigns(:issue).description).to be_nil
          end
        end
      end
    end
  end

  describe 'GET #discussions' do
    let(:issue) { create(:issue, project: project) }
    let!(:discussion) { create(:discussion_note_on_issue, noteable: issue, project: issue.project) }

    context 'with a related system note' do
      let(:confidential_issue) { create(:issue, :confidential, project: project) }
      let!(:system_note) { SystemNoteService.relate_issuable(issue, confidential_issue, user) }

      shared_examples 'user can see confidential issue' do |access_level|
        context "when a user is a #{access_level}" do
          before do
            project.add_member(user, access_level)
          end

          it 'displays related notes' do
            get :discussions, params: { namespace_id: project.namespace, project_id: project, id: issue.iid }

            discussions = json_response
            notes = discussions.flat_map { |d| d['notes'] }

            expect(discussions.count).to equal(2)
            expect(notes).to include(a_hash_including('id' => system_note.id.to_s))
          end
        end
      end

      shared_examples 'user cannot see confidential issue' do |access_level|
        context "when a user is a #{access_level}" do
          before do
            project.add_member(user, access_level)
          end

          it 'redacts note related to a confidential issue' do
            get :discussions, params: { namespace_id: project.namespace, project_id: project, id: issue.iid }

            discussions = json_response
            notes = discussions.flat_map { |d| d['notes'] }

            expect(discussions.count).to equal(1)
            expect(notes).not_to include(a_hash_including('id' => system_note.id.to_s))
          end
        end
      end

      context 'when authenticated' do
        before do
          sign_in(user)
        end

        %i[reporter developer maintainer].each do |access|
          it_behaves_like 'user can see confidential issue', access
        end

        it_behaves_like 'user cannot see confidential issue', :guest
      end

      context 'when unauthenticated' do
        let(:project) { create(:project, :public) }

        it_behaves_like 'user cannot see confidential issue', Gitlab::Access::NO_ACCESS
      end
    end
  end

  describe 'PUT #update' do
    let(:issue) { create(:issue, project: project) }

    def update_issue(issue_params: {}, additional_params: {}, id: nil)
      id ||= issue.iid
      params = {
        namespace_id: project.namespace.to_param,
        project_id: project,
        id: id,
        issue: { title: 'New title' }.merge(issue_params),
        format: :json
      }.merge(additional_params)

      put :update, params: params
    end

    context 'when changing the assignee' do
      let(:assignee) { create(:user) }

      before do
        project.add_developer(assignee)
        sign_in(assignee)
      end

      it 'exposes expected attributes' do
        update_issue(issue_params: { assignee_ids: [assignee.id] })

        expect(json_response['assignees'].first.keys)
          .to match_array(%w[id name username public_email avatar_url state locked web_url])
      end
    end
  end

  describe 'DescriptionDiffActions' do
    let_it_be(:project) { create(:project_empty_repo, :public) }

    context 'when issuable is an issue type issue' do
      it_behaves_like DescriptionDiffActions do
        let_it_be(:issuable) { create(:issue, project: project) }
        let_it_be(:version_1) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_2) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_3) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
      end
    end

    context 'when issuable is a task/work_item' do
      it_behaves_like DescriptionDiffActions do
        let_it_be(:issuable) { create(:issue, :task, project: project) }
        let_it_be(:version_1) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_2) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
        let_it_be(:version_3) { create(:description_version, issuable.base_class_name.underscore.to_sym => issuable) }
      end
    end
  end
end
