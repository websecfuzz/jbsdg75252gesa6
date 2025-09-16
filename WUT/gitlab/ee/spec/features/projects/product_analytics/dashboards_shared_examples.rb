# frozen_string_literal: true

require 'spec_helper'

# Shared examples for testing that the product analytics dashboards functionality works as expected
#
# The tests will check that a user can view the dashboards list, create/edit dashboards, and view dashboards.
# They also test that new dashboard data sources can be set up.
#
# The following let variables can be used to set up the testing environment:
# - `project_settings` - A hash of project settings that need to be set.
#   - An instrumentation key of some kind should be set on the project to test the product analytics data source
# - `application_settings` - A hash of application settings that need to be set.
#   - The `product_analytics_enabled?` application setting is enabled automatically
#
# Example
#
#   it_behaves_like 'product analytics dashboards' do
#     let(:project_settings) { { product_analytics_instrumentation_key: 456 } }
#     let(:application_settings) do
#     {
#       product_analytics_configurator_connection_string: 'https://configurator.example.com',
#       product_analytics_data_collector_host: 'https://collector.example.com',
#       cube_api_base_url: 'https://cube.example.com',
#       cube_api_key: '123'
#     }
#   end
RSpec.shared_examples 'product analytics dashboards' do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:query_response_with_unknown_error) { fixture_file('cube_js/query_with_error.json', dir: 'ee') }
  let_it_be(:query_response_with_no_db_error) { fixture_file('cube_js/query_with_no_db_error.json', dir: 'ee') }
  let_it_be(:query_response_with_data) { fixture_file('cube_js/query_with_data.json', dir: 'ee') }

  let(:cube_api_url) { "https://cube.example.com/cubejs-api/v1/load" }

  shared_examples 'does not render the product analytics list item' do
    before do
      visit_page
    end

    it do
      expect(page).not_to have_content(_('Product Analytics'))
    end
  end

  shared_examples 'renders the product analytics dashboards' do
    it do
      visit_page
      expect(page).to have_content('Understand your audience')
    end
  end

  shared_examples 'renders the setup view' do
    before do
      visit_page
    end

    it do
      expect(page).to have_content(s_('ProductAnalytics|Waiting for events'))
    end
  end

  shared_examples 'renders the new dashboard button' do
    before do
      visit_page
    end

    it do
      expect(page).to have_content(s_('Analytics|New dashboard'))
    end
  end

  context 'with the required application settings' do
    before do
      stub_application_setting(product_analytics_enabled?: true)
      stub_application_setting(**application_settings)
    end

    context 'with the feature flag disabled' do
      before do
        stub_feature_flags(product_analytics_features: false)
      end

      it_behaves_like 'does not render the product analytics list item'
    end

    context 'with the feature flag enabled' do
      before do
        stub_feature_flags(product_analytics_features: true)
      end

      context 'with the licensed feature disabled' do
        before do
          stub_licensed_features(combined_project_analytics_dashboards: true, product_analytics: false)
        end

        it_behaves_like 'does not render the product analytics list item'
      end

      context 'with the licensed feature enabled' do
        before do
          stub_licensed_features(combined_project_analytics_dashboards: true, product_analytics: true)
        end

        context 'with reporter permissions' do
          before do
            project.add_reporter(user)
          end

          it 'renders the onboarding list item' do
            visit_page
            expect(page).to have_content(s_('Product Analytics'))
            expect(page).to have_content(s_('Additional permissions required'))
          end

          it 'does not allow onboarding' do
            visit project_analytics_dashboards_path(project, vueroute: 'product-analytics-onboarding')
            wait_for_requests
            expect(page).to have_content(s_('Dashboard not found'))
          end
        end

        context 'with the correct user permissions' do
          before do
            project.add_maintainer(user)
          end

          it 'renders the onboarding list item' do
            visit_page
            expect(page).to have_content(s_('Product Analytics'))
          end

          context 'when setting up a new instance' do
            before do
              visit_page
              wait_for_requests
              click_link _('Set up')
            end

            it 'renders the provider selection view' do
              expect(page).to have_content(s_('ProductAnalytics|Analyze your product with Product Analytics'))
              expect(page).to have_content(s_('ProductAnalytics|Self-managed provider'))
            end

            context 'and selecting a self-managed provider' do
              it 'renders the creating instance loading screen and then the instrumentation setup page' do
                click_button s_('ProductAnalytics|Connect your own provider')

                expect(page).to have_content(s_('ProductAnalytics|Creating your product analytics instance…'))

                wait_for_requests

                project.project_setting.update!(project_settings)
                project.reload

                stub_cube_proxy_zero_count
                ::ProductAnalytics::InitializeStackService.new(container: project).unlock!

                travel_to(1.minute.from_now) do
                  expect(page).to have_content(s_('ProductAnalytics|Instrument your application'))
                end
              end
            end
          end

          context 'when the instance is loading' do
            before do
              project.project_setting.update!(project_settings)
              project.reload

              ::ProductAnalytics::InitializeStackService.new(container: project).lock!

              visit_page
              wait_for_requests
              click_link _('Continue set up')
            end

            it 'renders the loading view' do
              expect(page).to have_content(s_('ProductAnalytics|Creating your product analytics instance…'))
            end
          end

          context 'when waiting for events' do
            before do
              project.project_setting.update!(project_settings)
              project.reload

              ::ProductAnalytics::InitializeStackService.new(container: project).unlock!
            end

            context 'when the cube API returns an unhandled error' do
              before do
                stub_cube_proxy_error
                visit_page
              end

              it 'renders the error alert' do
                error_msg =
                  s_('ProductAnalytics|An error occurred while fetching data. Refresh the page to try again.')

                expect(find_by_testid('alert-danger')).to have_text(error_msg)
              end
            end

            context 'when the clickhouse database does not exist' do
              before do
                stub_cube_no_database_error
              end

              it_behaves_like 'renders the setup view'
            end

            context 'when the cube API returns zero data' do
              before do
                stub_cube_proxy_zero_count
              end

              it_behaves_like 'renders the setup view'
            end

            context 'when the cube API returns data' do
              before do
                stub_cube_proxy_success
              end

              it_behaves_like 'renders the product analytics dashboards'
            end

            context 'when the cube API returns data while onboarding' do
              before do
                stub_cube_proxy_zero_count
                visit_page
              end

              it 'renders the dashboard view after polling' do
                travel_to(1.minute.from_now) do
                  expect(page).to have_content(s_('ProductAnalytics|Waiting for events'))
                end

                stub_cube_proxy_success

                travel_to(1.minute.from_now) do
                  expect(page).to have_content('Understand your audience')
                end
              end
            end
          end

          context 'with the setup completed' do
            before do
              project.project_setting.update!(project_settings)
              stub_cube_proxy_success
            end

            it_behaves_like 'renders the product analytics dashboards'

            context 'when on a dashboards page' do
              before do
                visit project_analytics_dashboards_path(project, vueroute: :audience)
              end

              it 'has the dashboards page breadcrumb' do
                within_testid('breadcrumb-links') do
                  expect(page).to have_link(
                    s_('Analytics|Analytics dashboards'),
                    href: "#{project_analytics_dashboards_path(project)}/"
                  )

                  expect(page).to have_link(
                    s_('ProductAnalytics|Audience'),
                    href: "#"
                  )
                end
              end
            end

            context 'and a custom dashboard pointer is set' do
              before do
                create(:analytics_dashboards_pointer, :project_based, project: project)
              end

              it_behaves_like 'renders the new dashboard button'
            end

            context 'and the default custom dashboard location is used' do
              it_behaves_like 'renders the new dashboard button'

              it 'user can clone existing dashboard' do
                visit_page

                within first("[data-testid='dashboard-actions-dropdown']") do
                  click_button
                  within_testid('base-dropdown-menu') do
                    click_button 'Clone'
                  end
                end

                wait_for_requests

                expect(page).to have_content('Audience (Copy)')
              end
            end
          end
        end
      end
    end

    private

    def stub_cube_proxy_error
      stub_request(:post, cube_api_url)
        .to_return(status: 200, body: query_response_with_unknown_error, headers: {})
    end

    def stub_cube_no_database_error
      stub_request(:post, cube_api_url)
        .to_return(status: 404, body: query_response_with_no_db_error, headers: {})
    end

    def stub_cube_proxy_zero_count
      query_object = Gitlab::Json.parse(query_response_with_data)
      query_object['results'][0]['data'][0]['TrackedEvents.count'] = 0

      stub_request(:post, cube_api_url)
        .to_return(status: 200, body: query_object.to_json, headers: {})
    end

    def stub_cube_proxy_success
      query_object = Gitlab::Json.parse(query_response_with_data)

      stub_request(:post, cube_api_url)
        .to_return(status: 200, body: query_object.to_json, headers: {})
    end
  end
end
