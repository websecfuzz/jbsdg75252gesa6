# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::TracingController, feature_category: :observability do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let(:path) { nil }
  let(:observability_ff) { true }
  let(:expected_api_config) do
    {
      analyticsUrl: ::Gitlab::Observability.analytics_url(project),
      tracingUrl: Gitlab::Observability.tracing_url(project),
      tracingAnalyticsUrl: Gitlab::Observability.tracing_analytics_url(project),
      servicesUrl: Gitlab::Observability.services_url(project),
      operationsUrl: Gitlab::Observability.operations_url(project),
      metricsUrl: Gitlab::Observability.metrics_url(project),
      metricsSearchUrl: Gitlab::Observability.metrics_search_url(project),
      metricsSearchMetadataUrl: Gitlab::Observability.metrics_search_metadata_url(project),
      logsSearchUrl: Gitlab::Observability.logs_search_url(project),
      logsSearchMetadataUrl: Gitlab::Observability.logs_search_metadata_url(project)
    }
  end

  subject do
    get path
    response
  end

  before do
    stub_licensed_features(observability: true)
    stub_feature_flags(observability_features: observability_ff)
    sign_in(user)
  end

  shared_examples 'tracing route request' do
    context 'when user does not have permissions' do
      before_all do
        project.add_guest(user)
      end

      it 'returns 404' do
        expect(subject).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user has permissions' do
      before_all do
        project.add_reporter(user)
      end

      it 'returns 200' do
        expect(subject).to have_gitlab_http_status(:ok)
      end

      context 'when feature is disabled' do
        let(:observability_ff) { false }

        it 'returns 404' do
          expect(subject).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'GET #index' do
    let(:path) { project_tracing_index_path(project) }

    it_behaves_like 'tracing route request'

    describe 'html response' do
      before_all do
        project.add_reporter(user)
      end

      it 'renders the js-tracing element correctly' do
        element = Nokogiri::HTML.parse(subject.body).at_css('#js-tracing')

        expected_view_model = {
          apiConfig: expected_api_config,
          projectFullPath: project.full_path,
          projectId: project.id
        }.to_json
        expect(element.attributes['data-view-model'].value).to eq(expected_view_model)
      end
    end
  end

  describe 'GET #show' do
    let(:path) { project_tracing_path(project, id: "test-trace-id") }

    it_behaves_like 'tracing route request'

    describe 'html response' do
      before_all do
        project.add_reporter(user)
      end

      it 'renders the js-tracing element correctly' do
        element = Nokogiri::HTML.parse(subject.body).at_css('#js-tracing-details')

        expected_view_model = {
          apiConfig: expected_api_config,
          projectFullPath: project.full_path,
          projectId: project.id,
          traceId: 'test-trace-id',
          tracingIndexUrl: project_tracing_index_path(project),
          logsIndexUrl: namespace_project_logs_path(project.group, project),
          createIssueUrl: new_namespace_project_issue_path(project.group, project),
          metricsIndexUrl: namespace_project_metrics_path(project.group, project)
        }.to_json

        expect(element.attributes['data-view-model'].value).to eq(expected_view_model)
      end
    end
  end
end
