# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::MoveFunnelsWorker, feature_category: :product_analytics do
  let_it_be(:project) { create(:project) }
  let_it_be(:previous_custom_dashboard_project) { create(:project, :repository) }
  let_it_be(:new_custom_dashboard_project) { create(:project, :repository) }

  before do
    allow_next_instance_of(ProductAnalytics::Settings) do |settings|
      allow(settings).to receive(:product_analytics_configurator_connection_string).and_return('http://test:test@testdomain:4567')
    end
  end

  before_all do
    previous_custom_dashboard_project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/example1.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_1.yaml')),
      message: 'Add funnel',
      branch_name: 'master'
    )
    previous_custom_dashboard_project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/funnel_example_invalid_seconds.yml',
      File.open(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_invalid_seconds.yaml')),
      message: 'Add invalid seconds funnel definition',
      branch_name: 'master'
    )
    previous_custom_dashboard_project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/funnel_example_invalid_step.yml',
      File.open(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_invalid_step_name.yaml')),
      message: 'Add invalid step name funnel definition',
      branch_name: 'master'
    )
    new_custom_dashboard_project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/example1.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_changed.yaml')),
      message: 'Add funnel',
      branch_name: 'master'
    )
    new_custom_dashboard_project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/funnel_example_invalid_seconds.yml',
      File.open(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_invalid_seconds.yaml')),
      message: 'Add invalid seconds funnel definition',
      branch_name: 'master'
    )
    new_custom_dashboard_project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/funnel_example_invalid_step.yml',
      File.open(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_invalid_step_name.yaml')),
      message: 'Add invalid step name funnel definition',
      branch_name: 'master'
    )
  end

  describe "perform" do
    context "when feature flag is disabled" do
      before do
        stub_feature_flags(product_analytics_features: false)
      end

      it "does not call the configurator" do
        expect(Gitlab::HTTP).not_to receive(:post)

        described_class.new.perform(project.id, nil, new_custom_dashboard_project.id)
      end
    end

    context 'when using a local URL' do
      before do
        allow_next_instance_of(ProductAnalytics::Settings) do |settings|
          allow(settings).to receive(:product_analytics_configurator_connection_string).and_return('http://test:test@localhost:4567')
        end
      end

      context 'when the admin setting does not allow local requests' do
        before do
          allow(Gitlab::HTTP_V2::UrlBlocker)
            .to receive(:validate!)
            .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
        end

        it 'raises an invalid URL error' do
          expect do
            described_class.new.perform(project.id, nil, new_custom_dashboard_project.id)
          end.to raise_error(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)

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
                Addressable::URI.parse('http://test:test@localhost:4567/funnel-schemas'),
                'http://test:test@localhost:4567/funnel-schemas'
              ]
            )
        end

        it "calls configurator with 'created' funnel" do
          expect(Gitlab::HTTP)
            .to receive(:post) do |url, params|
            expect(url).to eq(
              URI::HTTP.build(
                host: 'localhost',
                port: '4567',
                path: '/funnel-schemas',
                userinfo: 'test:test'
              )
            )

            payload = ::Gitlab::Json.parse(params[:body]).with_indifferent_access

            expect(payload).to match(
              a_hash_including(
                project_ids: ["gitlab_project_#{project.id}"],
                funnels: [a_hash_including(
                  state: "created"
                )]
              )
            )
          end
            .once
            .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))

          described_class.new.perform(project.id, nil, new_custom_dashboard_project.id)
        end
      end
    end

    context "when previous custom project doesn't exist" do
      it "calls configurator with 'created' funnel" do
        expect(Gitlab::HTTP)
          .to receive(:post) do |url, params|
            expect(url).to eq(
              URI::HTTP.build(
                host: 'testdomain',
                port: '4567',
                path: '/funnel-schemas',
                userinfo: 'test:test'
              )
            )

            payload = ::Gitlab::Json.parse(params[:body]).with_indifferent_access

            expect(payload).to match(
              a_hash_including(
                project_ids: ["gitlab_project_#{project.id}"],
                funnels: [a_hash_including(
                  state: "created"
                )]
              )
            )
          end
          .once
          .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))

        described_class.new.perform(project.id, nil, new_custom_dashboard_project.id)
      end
    end

    context "when next custom project doesn't exist" do
      it "calls configurator with 'deleted' funnel" do
        expect(Gitlab::HTTP)
          .to receive(:post) do |url, params|
          expect(url).to eq(
            URI::HTTP.build(
              host: 'testdomain',
              port: '4567',
              path: '/funnel-schemas',
              userinfo: 'test:test'
            )
          )

          payload = ::Gitlab::Json.parse(params[:body]).with_indifferent_access

          expect(payload).to match(
            a_hash_including(
              project_ids: ["gitlab_project_#{project.id}"],
              funnels: [
                { name: "example1", state: "deleted" },
                { name: "funnel_example_invalid_seconds", state: "deleted" },
                { name: "funnel_example_invalid_step", state: "deleted" }
              ]
            )
          )
        end
          .once
          .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))

        described_class.new.perform(project.id, previous_custom_dashboard_project.id, nil)
      end
    end

    context "when both previous and next custom dashboard projects exist" do
      it "calls configurator with 'created' and 'deleted' funnels" do
        expect(Gitlab::HTTP)
          .to receive(:post) do |url, params|
          expect(url).to eq(
            URI::HTTP.build(
              host: 'testdomain',
              port: '4567',
              path: '/funnel-schemas',
              userinfo: 'test:test'
            )
          )

          payload = ::Gitlab::Json.parse(params[:body]).with_indifferent_access

          expect(payload).to match(
            a_hash_including(
              project_ids: ["gitlab_project_#{project.id}"],
              funnels: [
                { name: "example1", state: "deleted" },
                { name: "funnel_example_invalid_seconds", state: "deleted" },
                { name: "funnel_example_invalid_step", state: "deleted" },
                a_hash_including(
                  name: "example1",
                  state: "created"
                )
              ]
            )
          )
        end
          .once
          .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))

        described_class.new.perform(project.id, previous_custom_dashboard_project.id, new_custom_dashboard_project)
      end
    end
  end
end
