# frozen_string_literal: true

# The mock service can cause flakiness if it's started and stopped for each test, so we create it once before
# all tests and access it via an instance variable
module QA
  RSpec.describe(
    'Software Supply Chain Security',
    :requires_admin,
    :skip_live_env, # We need to enable local requests to use a local mock streaming server
    # and we can't create top-level groups in the paid tier on production
    product_group: :compliance,
    feature_flag: {
      name: 'use_consolidated_audit_event_stream_dest_api',
      scope: :group
    }
  ) do
    describe 'Group audit event streaming' do
      include_context 'with streamed events mock setup'

      let(:root_group) { create(:sandbox) }

      before(:context) do
        Runtime::ApplicationSettings.enable_local_requests
      end

      before do
        Runtime::Feature.disable(:disable_audit_event_streaming)
      end

      context 'with no destination' do
        let(:event_types) { %w[create_compliance_framework] }
        let(:headers) do
          {
            'Test-Header1': 'event streaming',
            'Test-Header2': 'group destination via ui'
          }
        end

        let(:stream_destination) do
          EE::Resource::ExternalAuditEventDestination.init do |resource|
            resource.destination_url = stream_destination_url
            resource.group = root_group
          end.reload!
        end

        it(
          'adds a streaming destination',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/422980'
        ) do
          Flow::Login.sign_in
          root_group.visit!
          Page::Group::Menu.perform(&:go_to_audit_events)
          EE::Page::Group::Secure::AuditEvents.perform do |audit_events|
            audit_events.click_streams_tab
            audit_events.add_streaming_destination('Smocker', stream_destination_url)

            expect(audit_events).to have_stream_destination('Smocker')

            stream_destination.add_headers(headers)
            stream_destination.add_filters(event_types)

            # We add a compliance framework to the group as a way to generate a streamed audit event so that we can
            # confirm that the mock service is ready to receive events.
            event_record = mock_service.wait_for_streaming_to_start(
              event_type: 'create_compliance_framework',
              entity_type: 'Group'
            ) do
              EE::Resource::ComplianceFramework.fabricate_via_api! do |framework|
                framework.group = root_group
              end.remove_via_api!
            end

            verify_response = mock_service.verify
            aggregate_failures do
              # Smocker treats header values as arrays
              # Verification tokens are created for us if we don't provide one
              # https://docs.gitlab.com/ee/administration/audit_event_streaming/#verify-event-authenticity
              expect(event_record[:headers]).to include(
                headers.transform_values { |v| [v] }
                  .merge("X-Gitlab-Event-Streaming-Token": [stream_destination.verification_token])
              )
              expect(verify_response).to be_success,
                "Failures when verifying events received:\n#{JSON.pretty_generate(verify_response.failures)}"
            end
          end
        end
      end

      context 'with a destination configured' do
        let(:target_details) { entity_path }
        let(:event_types) { %w[create_compliance_framework group_created project_group_link_created member_created] }
        let(:headers) do
          {
            'Test-Header1': 'test-header-value1',
            'Test-Header2': 'test-header-value2'
          }
        end

        let(:stream_destination) do
          EE::Resource::ExternalAuditEventDestination.fabricate_via_api! do |resource|
            resource.destination_url = stream_destination_url
            resource.group = root_group
            resource.name = "Smocker-#{Faker::Alphanumeric.alphanumeric(number: 8)}"
          end
        end

        before do
          stream_destination.add_headers(headers)
          stream_destination.add_filters(event_types)

          # We add a compliance framework to the group as a way to generate a streamed audit event so that we can
          # confirm that the mock service is ready to receive events.
          mock_service.wait_for_streaming_to_start(
            event_type: 'create_compliance_framework',
            entity_type: 'Group'
          ) do
            EE::Resource::ComplianceFramework.fabricate_via_api! do |framework|
              framework.group = root_group
            end.remove_via_api!
          end
        end

        context 'when a group is created' do
          let(:entity_path) do
            create(:group,
              sandbox: root_group,
              name: "audit-event-streaming-#{Faker::Alphanumeric.alphanumeric(number: 8)}").full_path
          end

          include_examples 'streamed events', 'group_created', 'Group', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/422984'
        end

        context 'when a project is shared with a group' do
          let(:project) { create(:project) }
          let(:target_details) { project.full_path }
          let(:entity_path) { root_group.full_path }

          before do
            project.invite_group(root_group)
          end

          include_examples 'streamed events', 'project_group_link_created', 'Group', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/422981'
        end

        context 'when a user is added to a group' do
          let(:user) { create(:user) }
          let(:target_details) { user.name }
          let(:entity_path) { root_group.full_path }

          before do
            root_group.add_member(user)
          end

          include_examples 'streamed events', 'member_created', 'Group', 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/422983'
        end
      end
    end
  end
end
