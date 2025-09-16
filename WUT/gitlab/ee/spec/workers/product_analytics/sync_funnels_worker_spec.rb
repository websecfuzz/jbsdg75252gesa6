# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductAnalytics::SyncFunnelsWorker, feature_category: :product_analytics do
  RSpec.shared_examples 'sends data to configurator' do
    context 'when a new funnel is in the commit' do
      before do
        create_valid_funnel
      end

      after do
        delete_funnel("example1.yml")
      end

      it 'is successful' do
        url_to_projects_regex.each do |url, projects_regex|
          expect(Gitlab::HTTP).to receive(:post)
            .with(URI.parse(url.to_s), {
              allow_local_requests: allow_local_requests,
              body: Regexp.new(projects_regex.source + /.*"state":"created"/.source)
            }).once
            .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))
        end

        worker
      end

      context 'when the new funnel is invalid' do
        before do
          create_invalid_funnel
        end

        after do
          delete_funnel("funnel_example_invalid_step.yml")
        end

        it 'does not attempt to post to the API' do
          expect(Gitlab::HTTP).not_to receive(:post)

          worker
        end
      end
    end

    context 'when an updated funnel is in the commit' do
      before do
        create_valid_funnel
        update_funnel
      end

      after do
        delete_funnel("example1.yml")
      end

      it 'is successful' do
        url_to_projects_regex.each do |url, projects_regex|
          expect(Gitlab::HTTP).to receive(:post)
            .with(URI.parse(url.to_s), {
              allow_local_requests: allow_local_requests,
              body: Regexp.new(projects_regex.source + /.*"state":"updated"/.source)
            }).once.and_return(instance_double("HTTParty::Response",
              body: { result: 'success' }))
        end

        worker
      end

      context 'when the updated funnel is invalid' do
        before do
          create_invalid_funnel
          update_invalid_funnel
        end

        after do
          delete_funnel("funnel_example_invalid_step.yml")
        end

        it 'does not attempt to post to the API' do
          expect(Gitlab::HTTP).not_to receive(:post)

          worker
        end
      end
    end

    context 'when an renamed funnel is in the commit' do
      before do
        create_valid_funnel
        rename_valid_funnel
      end

      after do
        delete_funnel("example2.yml")
      end

      it 'is successful' do
        url_to_projects_regex.each do |url, _projects_regex|
          expect(Gitlab::HTTP).to receive(:post)
            .with(URI.parse(url.to_s), {
              allow_local_requests: allow_local_requests,
              body: /"previous_name":"example1"/
            }).once
            .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))
        end

        worker
      end

      context 'when the renamed funnel is invalid' do
        before do
          create_invalid_funnel
          rename_invalid_funnel
        end

        after do
          delete_funnel("funnel_example_invalid_seconds.yml")
        end

        it 'does not attempt to post to the API' do
          expect(Gitlab::HTTP).not_to receive(:post)

          worker
        end
      end
    end

    context 'when a deleted funnel is in the commit' do
      before do
        create_valid_funnel
        delete_funnel("example1.yml")
      end

      it 'is successful' do
        url_to_projects_regex.each do |url, _projects_regex|
          expect(Gitlab::HTTP).to receive(:post)
            .with(URI.parse(url.to_s), {
              allow_local_requests: allow_local_requests,
              body: Regexp.new(/.*deleted/.source)
            }).once
            .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))
        end

        worker
      end

      context 'when the deleted funnel is invalid' do
        before do
          create_invalid_funnel
          delete_funnel("funnel_example_invalid_step.yml")
        end

        it 'is successful' do
          url_to_projects_regex.each do |url, projects_regex|
            expect(Gitlab::HTTP).to receive(:post)
              .with(URI.parse(url.to_s), {
                allow_local_requests: allow_local_requests,
                body: Regexp.new(projects_regex.source + /.*deleted/.source)
              }).once
              .and_return(instance_double("HTTParty::Response", body: { result: 'success' }))
          end

          worker
        end
      end
    end

    context 'when no new or updated funnels are in the commit' do
      before do
        commit_with_no_funnel
      end

      after do
        project.repository.delete_file(
          project.creator,
          'readme.md',
          message: 'delete readme',
          branch_name: 'master'
        )
      end

      it 'does not attempt to post to the API' do
        expect(Gitlab::HTTP).not_to receive(:post)

        worker
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(product_analytics_features: false)
        create_valid_funnel
      end

      after do
        delete_funnel("example1.yml")
      end

      it 'does not attempt to post to the API' do
        expect(Gitlab::HTTP).not_to receive(:post)

        worker
      end
    end
  end

  include RepoHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, namespace: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:other_project_1) { create(:project, namespace: group) }
  let_it_be(:other_project_2) { create(:project, namespace: group) }

  let(:commit) { project.repository.commit }

  subject(:worker) { described_class.new.perform(project.id, commit.sha, user.id) }

  describe '#perform' do
    context 'when using a local URL' do
      before do
        allow_next_instance_of(ProductAnalytics::Settings) do |settings|
          allow(settings).to receive(:product_analytics_configurator_connection_string).and_return('http://test:test@localhost:4567')
        end
        project.project_setting.update!(product_analytics_instrumentation_key: 'some_key')
        project.reload
      end

      context 'when the admin setting does not allow local requests' do
        before do
          create_valid_funnel

          allow(Gitlab::HTTP_V2::UrlBlocker)
            .to receive(:validate!)
            .and_raise(Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
        end

        after do
          delete_funnel("example1.yml")
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
                Addressable::URI.parse('http://test:test@localhost:4567/funnel-schemas'),
                'http://test:test@localhost:4567/funnel-schemas'
              ]
            )
        end

        it_behaves_like 'sends data to configurator' do
          let(:allow_local_requests) { true }
          let(:url_to_projects_regex) do
            { "http://test:test@localhost:4567/funnel-schemas": /gitlab_project_#{project.id}/ }
          end
        end
      end
    end

    context 'without pointer projects' do
      before do
        allow_next_instance_of(ProductAnalytics::Settings) do |settings|
          allow(settings).to receive(:product_analytics_configurator_connection_string).and_return('http://test:test@anotherhost:4567')
        end
        project.project_setting.update!(product_analytics_instrumentation_key: 'some_key')
        project.reload
      end

      it_behaves_like 'sends data to configurator' do
        let(:allow_local_requests) { false }
        let(:url_to_projects_regex) do
          { "http://test:test@anotherhost:4567/funnel-schemas": /gitlab_project_#{project.id}/ }
        end
      end

      context "when the connection string ends with /" do
        before do
          allow_next_instance_of(ProductAnalytics::Settings) do |settings|
            allow(settings).to receive(:product_analytics_configurator_connection_string).and_return('http://test:test@anotherhost:4567/')
          end
        end

        it_behaves_like 'sends data to configurator' do
          let(:allow_local_requests) { false }
          let(:url_to_projects_regex) do
            { "http://test:test@anotherhost:4567/funnel-schemas": /gitlab_project_#{project.id}/ }
          end
        end
      end
    end

    context 'with pointer projects' do
      before do
        other_project_1.project_setting.update!(product_analytics_instrumentation_key: 'some_key')
        other_project_2.project_setting.update!(product_analytics_instrumentation_key: 'some_key')
        other_project_1.reload
        other_project_2.reload
      end

      context 'with single pointer project' do
        before do
          Analytics::DashboardsPointer.create!(project: other_project_1, target_project: project)
          other_project_1.project_setting.update!(
            product_analytics_configurator_connection_string: 'http://test:test@anotherhost:4567',
            product_analytics_data_collector_host: 'http://test.net',
            cube_api_base_url: 'https://test.com:3000',
            cube_api_key: 'helloworld'
          )
          other_project_1.reload
        end

        it_behaves_like 'sends data to configurator' do
          let(:allow_local_requests) { false }
          let(:url_to_projects_regex) do
            { "http://test:test@anotherhost:4567/funnel-schemas": /gitlab_project_#{other_project_1.id}/ }
          end
        end
      end

      context 'with multiple pointer projects' do
        before do
          Analytics::DashboardsPointer.create!(project: other_project_1, target_project: project)
          Analytics::DashboardsPointer.create!(project: other_project_2, target_project: project)
        end

        context "when projects are using the same configurator" do
          before do
            other_project_1.project_setting.update!(
              product_analytics_configurator_connection_string: 'http://test:test@anotherhost:4567',
              product_analytics_data_collector_host: 'http://test.net',
              cube_api_base_url: 'https://test.com:3000',
              cube_api_key: 'helloworld'
            )
            other_project_1.reload
            other_project_2.project_setting.update!(
              product_analytics_configurator_connection_string: 'http://test:test@anotherhost:4567',
              product_analytics_data_collector_host: 'http://test.net',
              cube_api_base_url: 'https://test.com:3000',
              cube_api_key: 'helloworld'
            )
            other_project_2.reload
          end

          it_behaves_like 'sends data to configurator' do
            # rubocop:disable Layout/LineLength -- regex must be on a single line
            let(:regex) do
              /gitlab_project_#{other_project_1.id}.*gitlab_project_#{other_project_2.id}|gitlab_project_#{other_project_2.id}.*gitlab_project_#{other_project_1.id}/
            end

            # rubocop:enable Layout/LineLength
            let(:allow_local_requests) { false }
            let(:url_to_projects_regex) do
              {
                "http://test:test@anotherhost:4567/funnel-schemas": regex
              }
            end
          end
        end

        context "when projects are using different configurators" do
          before do
            other_project_1.project_setting.update!(
              product_analytics_configurator_connection_string: 'http://test:test@anotherhost:4567',
              product_analytics_data_collector_host: 'http://test.net',
              cube_api_base_url: 'https://test.com:3000',
              cube_api_key: 'helloworld'
            )
            other_project_2.project_setting.update!(
              product_analytics_configurator_connection_string: 'http://test:test@test.net:4567',
              product_analytics_data_collector_host: 'http://test.net',
              cube_api_base_url: 'https://test.com:3000',
              cube_api_key: 'helloworld'
            )
            other_project_1.reload
            other_project_2.reload
          end

          it_behaves_like 'sends data to configurator' do
            let(:allow_local_requests) { false }
            let(:url_to_projects_regex) do
              {
                "http://test:test@anotherhost:4567/funnel-schemas": /gitlab_project_#{other_project_1.id}/,
                "http://test:test@test.net:4567/funnel-schemas": /gitlab_project_#{other_project_2.id}/
              }
            end
          end
        end
      end
    end
  end

  private

  def commit_with_no_funnel
    project.repository.create_file(
      project.creator,
      'readme.md',
      'test file',
      message: 'Add readme',
      branch_name: 'master'
    )
  end

  def create_valid_funnel
    project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/example1.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_1.yaml')),
      message: 'Add funnel',
      branch_name: 'master'
    )
  end

  def create_invalid_funnel
    project.repository.create_file(
      project.creator,
      '.gitlab/analytics/funnels/funnel_example_invalid_step.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_invalid_step_name.yaml')),
      message: 'Add invalid funnel',
      branch_name: 'master'
    )
  end

  def rename_valid_funnel
    project.repository.update_file(
      project.creator,
      '.gitlab/analytics/funnels/example2.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_changed.yaml')),
      message: 'Rename funnel',
      branch_name: 'master',
      previous_path: '.gitlab/analytics/funnels/example1.yml'
    )
  end

  def rename_invalid_funnel
    project.repository.update_file(
      project.creator,
      '.gitlab/analytics/funnels/funnel_example_invalid_seconds.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_invalid_seconds.yaml')),
      message: 'Rename invalid funnel',
      branch_name: 'master',
      previous_path: '.gitlab/analytics/funnels/funnel_example_invalid_step.yml'
    )
  end

  def update_funnel
    project.repository.update_file(
      project.creator,
      '.gitlab/analytics/funnels/example1.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_changed.yaml')),
      message: 'Update funnel',
      branch_name: 'master'
    )
  end

  def update_invalid_funnel
    project.repository.update_file(
      project.creator,
      '.gitlab/analytics/funnels/funnel_example_invalid_step.yml',
      File.read(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_invalid_step_name.yaml')),
      message: 'Update invalid funnel',
      branch_name: 'master'
    )
  end

  def delete_funnel(filename)
    project.repository.delete_file(
      project.creator,
      ".gitlab/analytics/funnels/#{filename}",
      message: 'delete funnel',
      branch_name: 'master'
    )
  end
end
