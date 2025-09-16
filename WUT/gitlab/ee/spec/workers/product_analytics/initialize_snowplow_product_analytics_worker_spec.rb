# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::InitializeSnowplowProductAnalyticsWorker, feature_category: :product_analytics do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: create(:group)) }

  let(:app_id) { SecureRandom.hex(16) }

  subject(:worker) { described_class.new.perform(project.id) }

  before do
    allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(true)
    stub_licensed_features(product_analytics: true)
    stub_feature_flags(product_analytics_features: true)
    stub_application_setting(product_analytics_configurator_connection_string: 'https://gl-product-analytics-configurator.gl.com:4567')
  end

  shared_examples 'a worker that did not make any HTTP calls' do
    it 'makes no HTTP calls to the configurator API' do
      worker

      expect(Gitlab::HTTP).not_to receive(:post)
    end
  end

  context 'when response is successful' do
    before do
      stub_request(:post, "https://gl-product-analytics-configurator.gl.com:4567/setup-project/gitlab_project_#{project.id}")
        .to_return(status: 200, body: { app_id: app_id, db_name: "gitlab_project_#{project.id}" }.to_json, headers: {})
    end

    it 'persists the instrumentation key' do
      expect { worker }
        .to change { project.reload.project_setting.product_analytics_instrumentation_key }.from(nil).to(app_id)
    end

    it 'ensures the temporary redis key is deleted' do
      worker

      expect(
        Gitlab::Redis::SharedState.with { |redis| redis.get("project:#{project.id}:product_analytics_initializing") }
      ).to eq(nil)
    end

    it 'tracks the success' do
      expect(Gitlab::UsageDataCounters::HLLRedisCounter)
        .to receive(:track_usage_event).with('project_initialized_product_analytics', project.id)

      worker
    end

    context 'when project-level connection string is set' do
      before do
        stub_application_setting(product_analytics_configurator_connection_string: '')
        project.project_setting.update!(
          product_analytics_configurator_connection_string: 'https://gl-product-analytics-configurator.gl.com:4567',
          product_analytics_data_collector_host: 'http://test.net',
          cube_api_base_url: 'https://test.com:3000',
          cube_api_key: 'helloworld'
        )
      end

      it 'persists the instrumentation key' do
        expect { worker }
          .to change { project.reload.project_setting.product_analytics_instrumentation_key }.from(nil).to(app_id)
      end
    end
  end

  context 'when response is unsuccessful' do
    before do
      stub_request(:post, "https://gl-product-analytics-configurator.gl.com:4567/setup-project/gitlab_project_#{project.id}")
        .to_return(status: 401, body: {}.to_json, headers: {})
    end

    it 'raises a RuntimeError' do
      expect(Gitlab::ErrorTracking).to receive(:track_and_raise_exception).twice.and_call_original
      expect { worker }.to raise_error(RuntimeError)
    end
  end

  context 'when using a local URL' do
    before do
      stub_application_setting(product_analytics_configurator_connection_string: 'http://test:test@localhost:4567')
    end

    context 'when the admin setting does not allow local requests' do
      before do
        allow(Gitlab::HTTP_V2::UrlBlocker)
          .to receive(:validate!)
          .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
      end

      it 'raises an invalid URL error' do
        expect { worker }.to raise_error(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
        expect(Gitlab::HTTP).not_to receive(:post)
      end
    end

    context 'when the admin setting allows local requests' do
      before do
        stub_application_setting(allow_local_requests_from_web_hooks_and_services: true)

        allow(Gitlab::HTTP_V2::UrlBlocker)
          .to receive(:validate!)
          .and_return(
            [
              Addressable::URI.parse("http://test:test@localhost:4567/setup-project/gitlab_project_#{project.id}"),
              "http://test:test@localhost:4567/setup-project/gitlab_project_#{project.id}"
            ]
          )

        allow(Gitlab::HTTP)
          .to receive(:post)
          .with(
            Addressable::URI.parse("http://test:test@localhost:4567/setup-project/gitlab_project_#{project.id}"),
            allow_local_requests: true,
            timeout: 10
          )
          .and_return(
            instance_double(
              HTTParty::Response,
              code: 200,
              success?: true,
              body: { app_id: app_id, project_id: "gitlab_project_#{project.id}" }.to_json
            )
          )
      end

      it 'persists the instrumentation key' do
        expect { worker }
          .to change { project.reload.project_setting.product_analytics_instrumentation_key }.from(nil).to(app_id)
      end
    end
  end

  context 'when feature is not licensed' do
    before do
      stub_licensed_features(product_analytics: false)
    end

    it_behaves_like 'a worker that did not make any HTTP calls'
  end

  context 'when the feature flag is disabled' do
    before do
      stub_feature_flags(product_analytics_features: false)
    end

    it_behaves_like 'a worker that did not make any HTTP calls'
  end

  context 'when the instance product analytics toggle is disabled' do
    before do
      allow(Gitlab::CurrentSettings).to receive(:product_analytics_enabled?).and_return(false)
    end

    it_behaves_like 'a worker that did not make any HTTP calls'
  end
end
