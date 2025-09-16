# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ci::Runner, feature_category: :runner do
  let_it_be_with_reload(:project) { create(:project, :repository, :in_group, :allow_runner_registration_token) }

  let_it_be_with_reload(:user) { create(:user, developer_of: project) }
  let_it_be(:ref) { 'master' }
  let_it_be(:runner) { create(:ci_runner, :project, projects: [project]) }

  describe '/api/v4/jobs', feature_category: :continuous_integration do
    include Ci::JobTokenScopeHelpers

    let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: ref) }

    describe 'POST /api/v4/jobs/request' do
      context 'secrets management' do
        let(:valid_secrets) do
          {
            DATABASE_PASSWORD: {
              vault: {
                engine: { name: 'kv-v2', path: 'kv-v2' },
                path: 'production/db',
                field: 'password'
              },
              file: true
            }
          }
        end

        let!(:ci_build) { create(:ci_build, :pending, :queued, pipeline: pipeline, secrets: secrets) }

        context 'when secrets management feature is available' do
          before do
            stub_licensed_features(ci_secrets_management: true)
          end

          context 'when job has secrets configured' do
            let(:secrets) { valid_secrets }

            context 'when runner does not support secrets' do
              it 'sets "runner_unsupported" failure reason and does not expose the build at all' do
                request_job

                expect(ci_build.reload).to be_runner_unsupported
                expect(response).to have_gitlab_http_status(:no_content)
              end
            end

            context 'when runner supports secrets' do
              before do
                create(:ci_variable, project: project, key: 'VAULT_SERVER_URL', value: 'https://vault.example.com')
                create(:ci_variable, project: project, key: 'VAULT_AUTH_ROLE', value: 'production')
              end

              it 'returns secrets configuration' do
                request_job_with_secrets_supported

                expect(response).to have_gitlab_http_status(:created)
                expect(json_response['secrets']).to eq(
                  {
                    'DATABASE_PASSWORD' => {
                      'vault' => {
                        'server' => {
                          'url' => 'https://vault.example.com',
                          'namespace' => nil,
                          'auth' => {
                            'name' => 'jwt',
                            'path' => 'jwt',
                            'data' => {
                              'jwt' => '${CI_JOB_JWT}',
                              'role' => 'production'
                            }
                          }
                        },
                        'engine' => { 'name' => 'kv-v2', 'path' => 'kv-v2' },
                        'path' => 'production/db',
                        'field' => 'password'
                      },
                      'file' => true
                    }
                  }
                )
              end
            end
          end

          context 'job does not have secrets configured' do
            let(:secrets) { {} }

            it 'doesn not return secrets configuration' do
              request_job_with_secrets_supported

              expect(response).to have_gitlab_http_status(:created)
              expect(json_response['secrets']).to eq({})
            end
          end
        end

        context 'when secrets management feature is not available' do
          before do
            stub_licensed_features(ci_secrets_management: false)
          end

          context 'job has secrets configured' do
            let(:secrets) { valid_secrets }

            it 'does not return secrets configuration' do
              request_job_with_secrets_supported

              expect(response).to have_gitlab_http_status(:created)
              expect(json_response['secrets']).to eq(nil)
            end
          end
        end
      end

      describe '#policy_options', feature_category: :security_policy_management do
        let!(:ci_build) { create(:ee_ci_build, :pending, :queued, *job_traits, pipeline: pipeline) }
        let(:job_traits) { [] }

        it 'does not include policy_options' do
          request_job

          expect(json_response).not_to include('policy_options')
        end

        context 'when feature is licensed' do
          before do
            stub_licensed_features(security_orchestration_policies: true)
          end

          it 'includes nil policy_options' do
            request_job

            expect(json_response).to match(a_hash_including('policy_options' => nil))
          end

          context 'with execution policy job' do
            let(:job_traits) { %i[execution_policy_job] }

            it 'includes correct policy_options' do
              request_job

              expect(json_response).to match(a_hash_including('policy_options' => {
                'execution_policy_job' => true,
                'policy_name' => 'My policy'
              }))
            end

            context 'with variables_override' do
              let(:job_traits) { %i[execution_policy_job_with_variables_override] }

              it 'includes correct policy_options' do
                request_job

                expect(json_response).to match(a_hash_including('policy_options' => {
                  'execution_policy_job' => true,
                  'policy_name' => 'My policy',
                  'policy_variables_override_allowed' => false,
                  'policy_variables_override_exceptions' => %w[TEST_VAR]
                }))
              end
            end
          end
        end
      end

      def request_job_with_secrets_supported
        request_job info: { features: { vault_secrets: true } }
      end

      def request_job(token = runner.token, **params)
        post api('/jobs/request'), params: params.merge(token: token)
      end
    end

    describe 'GET api/v4/jobs/:id/artifacts' do
      let_it_be_with_reload(:job_with_artifacts) do
        create(:ci_build, :success, ref: ref, pipeline: pipeline, user: user, project: project)
      end

      let(:job) { job_with_artifacts }
      let(:token) { job.token }

      before_all do
        create(:ci_job_artifact, :archive, job: job_with_artifacts, project: project)
      end

      shared_examples 'successful artifact download' do
        before do
          project.group.root_ancestor.external_audit_event_destinations.create!(destination_url: 'http://example.com')
          stub_licensed_features(admin_audit_log: true, extended_audit_events: true, external_audit_events: true)
        end

        it 'downloads artifacts', :aggregate_failures do
          expect(::Gitlab::Audit::Auditor).to(
            receive(:audit).with(hash_including(name: 'user_authenticated_using_job_token'))
          ).and_call_original
          expect(::Gitlab::Audit::Auditor).to(
            receive(:audit).with(hash_including(name: 'job_artifact_downloaded'))
          ).and_call_original
          expect(AuditEvents::AuditEventStreamingWorker).to(
            receive(:perform_async)
              .with('job_artifact_downloaded', nil, a_string_including("Downloaded artifact"))
          ).and_call_original

          download_artifact

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      shared_examples 'forbidden request' do
        it 'responds with forbidden' do
          download_artifact

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with missing artifacts file', :aggregate_failures do
        let(:job_without_artifacts) do
          create(:ci_build, :success, ref: ref, pipeline: pipeline, user: user, project: project)
        end

        it 'returns not_found and does not audit' do
          expect(::Ci::ArtifactDownloadAuditor).not_to receive(:new)
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          # Use bearer to avoid HTTP 401 unauthorized response
          pat = create :personal_access_token, user: user, scopes: %w[api]
          bearer = { 'Authorization' => "Bearer #{pat.token}" }

          get api("/jobs/#{job_without_artifacts.id}/artifacts"), headers: bearer

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when a job has a cross-project dependency' do
        let_it_be(:downstream_project) { create(:project) }
        let_it_be_with_reload(:downstream_project_dev) { create(:user) }

        let_it_be(:options) do
          {
            cross_dependencies: [
              {
                project: project.full_path,
                ref: ref,
                job: job_with_artifacts.name,
                artifacts: true
              }
            ]

          }
        end

        let_it_be_with_reload(:downstream_ci_build) do
          create(:ci_build, :running, project: downstream_project, user: user, options: options)
        end

        let(:token) { downstream_ci_build.token }
        let(:job) { job_with_artifacts } # Use the job with artifacts for downloads

        before_all do
          downstream_project.add_developer(user)
          downstream_project.add_developer(downstream_project_dev)
          make_project_fully_accessible(downstream_project, project)
        end

        context 'when feature is available through license' do
          before do
            stub_licensed_features(cross_project_pipelines: true)
          end

          context 'when the job is created by a user with sufficient permission in upstream project' do
            it_behaves_like 'successful artifact download'

            context 'and the upstream project has disabled public builds' do
              before do
                project.update!(public_builds: false)
              end

              it_behaves_like 'successful artifact download'
            end
          end

          context 'when the job is created by a user without sufficient permission in upstream project' do
            before do
              downstream_ci_build.update!(user: downstream_project_dev)
            end

            it_behaves_like 'forbidden request'

            context 'and the upstream project has disabled public builds' do
              before do
                project.update!(public_builds: false)
              end

              it_behaves_like 'forbidden request'
            end
          end

          context 'when the upstream project is public and the job user does not have permission in the project' do
            before do
              project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
              downstream_ci_build.update!(user: downstream_project_dev)
            end

            it_behaves_like 'successful artifact download'

            context 'and the upstream project has disabled public builds' do
              before do
                project.update!(public_builds: false)
              end

              it_behaves_like 'forbidden request'
            end
          end
        end

        context 'when feature is available through usage ping features' do
          before do
            stub_usage_ping_features(true)
          end

          context 'when the job is created by a user with sufficient permission in upstream project' do
            it_behaves_like 'successful artifact download'

            context 'and the upstream project has disabled public builds' do
              before do
                project.update!(public_builds: false)
              end

              it_behaves_like 'successful artifact download'
            end
          end
        end
      end

      def download_artifact(params: {}, request_headers: headers)
        params[:token] = token unless params.key?(:token)
        job.reload
        get api("/jobs/#{job.id}/artifacts"), params: params, headers: request_headers
      end
    end
  end

  describe '/api/v4/runners', feature_category: :runner do
    describe 'POST /api/v4/runners' do
      let(:params) { { token: project.runners_token } }

      subject(:register_runner) { post api('/runners'), params: params }

      it 'registers a runner on project and logs audit event', :aggregate_failures do
        expect_next_instance_of(::AuditEvents::RunnerAuditEventService) do |service|
          expect(service).to receive(:track_event).and_call_original
        end

        expect { register_runner }
          .to change { Ci::Runner.belonging_to_project(project).count }.by(1)
          .and change { AuditEvent.count }.by(1)
        expect(response).to have_gitlab_http_status(:created)
      end
    end

    describe 'DELETE /api/v4/runners' do
      let!(:runner) { create(:ci_runner, :project, projects: [project]) }
      let(:params) { { token: runner.token } }

      subject(:delete_runner) { delete api('/runners'), params: params }

      it 'deletes runner and logs audit event', :aggregate_failures do
        expect_next_instance_of(::AuditEvents::RunnerAuditEventService) do |service|
          expect(service).to receive(:track_event).and_call_original
        end

        expect { delete_runner }
          .to change { Ci::Runner.belonging_to_project(project).count }.by(-1)
          .and change { AuditEvent.count }.by(1)
        expect(response).to have_gitlab_http_status(:no_content)
      end
    end
  end
end
