# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::AuditEvents, :aggregate_failures, feature_category: :audit_events do
  describe 'Unique usage tracking', :clean_gitlab_redis_shared_state do
    let_it_be(:current_user) { create(:admin) }
    let_it_be(:group) { create(:group, owner_id: current_user) }
    let_it_be(:project) { create(:project) }

    before do
      project.add_member(current_user, :maintainer)
    end

    context 'after calling all audit_events APIs as a single licensed user', :enable_admin_mode do
      before do
        stub_licensed_features(admin_audit_log: true)
        stub_feature_flags(read_audit_events_from_new_tables: false)
      end

      subject do
        travel_to 8.days.ago do
          get api('/audit_events', current_user)
          get api("/groups/#{group.id}/audit_events", current_user)
          get api("/projects/#{project.id}/audit_events", current_user)
        end
      end

      it 'tracks 3 separate events' do
        expect(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event).exactly(3).times
                                                                  .with('a_compliance_audit_events_api', values: current_user.id)
        # user activity tracking is also recorded
        expect(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
                                                                  .with('unique_active_user', values: current_user.id)
        subject
      end

      it 'reports one unique event' do
        subject

        expect(Gitlab::UsageDataCounters::HLLRedisCounter.unique_events(event_names: 'a_compliance_audit_events_api', start_date: 2.months.ago, end_date: Date.current)).to eq(1)
      end
    end
  end

  describe 'GET /audit_events' do
    let(:url) { "/audit_events" }

    context 'when authenticated, as a user' do
      let(:user) { create(:user) }

      it_behaves_like '403 response' do
        let(:request) { get api(url, user) }
      end
    end

    context 'when authenticated, as an admin' do
      let_it_be(:admin) { create(:admin) }

      context 'audit events feature is not available' do
        it_behaves_like '403 response' do
          let(:request) { get api(url, admin, admin_mode: true) }
        end
      end

      context 'audit events feature is available' do
        let_it_be(:user_audit_event) { create(:user_audit_event, created_at: Date.new(2000, 1, 10)) }
        let_it_be(:project_audit_event) { create(:project_audit_event, created_at: Date.new(2000, 1, 15)) }
        let_it_be(:group_audit_event) { create(:group_audit_event, created_at: Date.new(2000, 1, 20)) }

        before do
          stub_licensed_features(admin_audit_log: true)
          stub_feature_flags(read_audit_events_from_new_tables: false)
        end

        it_behaves_like 'GET request permissions for admin mode' do
          let(:path) { url }
        end

        it 'returns 200 response' do
          get api(url, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'includes the correct pagination headers' do
          audit_events_counts = AuditEvent.count

          get api(url, admin, admin_mode: true)

          expect(response).to include_pagination_headers
          expect(response.headers['X-Total']).to eq(audit_events_counts.to_s)
          expect(response.headers['X-Page']).to eq('1')
        end

        context 'parameters' do
          it_behaves_like 'an endpoint with keyset pagination' do
            let(:first_record) { group_audit_event }
            let(:second_record) { project_audit_event }
            let(:api_call) { api(url, admin, admin_mode: true) }
          end

          context 'entity_type parameter' do
            it "returns audit events of the provided entity type" do
              get api(url, admin, admin_mode: true), params: { entity_type: 'User' }

              expect(json_response.size).to eq 1
              expect(json_response.first["id"]).to eq(user_audit_event.id)
            end

            context 'when entity_type is Gitlab::Audit::InstanceScope' do
              let_it_be(:instance_audit_event) { create(:instance_audit_event) }

              it 'returns audit events of instance entity_type' do
                get api(url, admin, admin_mode: true), params: { entity_type: 'Gitlab::Audit::InstanceScope' }

                expect(json_response.size).to eq 1
                expect(json_response.first["id"]).to eq(instance_audit_event.id)
              end
            end
          end

          context 'entity_id parameter' do
            context 'requires entity_type parameter to be present' do
              it_behaves_like '400 response' do
                let(:request) { get api(url, admin, admin_mode: true), params: { entity_id: 1 } }
              end
            end

            it 'returns audit_events of the provided entity id' do
              get api(url, admin, admin_mode: true), params: { entity_type: 'User', entity_id: user_audit_event.entity_id }

              expect(json_response.size).to eq 1
              expect(json_response.first["id"]).to eq(user_audit_event.id)
            end
          end

          context 'created_before parameter' do
            it "returns audit events created before the given parameter" do
              created_before = '2000-01-20T00:00:00.060Z'

              get api(url, admin, admin_mode: true), params: { created_before: created_before }

              expect(json_response.size).to eq 3
              expect(json_response.first["id"]).to eq(group_audit_event.id)
              expect(json_response.last["id"]).to eq(user_audit_event.id)
            end
          end

          context 'created_after parameter' do
            it "returns audit events created after the given parameter" do
              created_after = '2000-01-12T00:00:00.060Z'

              get api(url, admin, admin_mode: true), params: { created_after: created_after }

              expect(json_response.size).to eq 2
              expect(json_response.first["id"]).to eq(group_audit_event.id)
              expect(json_response.last["id"]).to eq(project_audit_event.id)
            end
          end
        end

        context 'attributes' do
          it 'exposes the right attributes' do
            get api(url, admin, admin_mode: true), params: { entity_type: 'User' }

            response = json_response.first
            details = response['details']

            expect(response["id"]).to eq(user_audit_event.id)
            expect(response["author_id"]).to eq(user_audit_event.user.id)
            expect(response["entity_id"]).to eq(user_audit_event.entity_id)
            expect(response["entity_type"]).to eq('User')
            expect(Time.parse(response["created_at"])).to be_like_time(user_audit_event.created_at)
            expect(details).to eq user_audit_event.formatted_details.with_indifferent_access
          end
        end

        context 'with new audit tables (feature flag enabled)' do
          before do
            stub_feature_flags(read_audit_events_from_new_tables: true)
          end

          let_it_be(:new_project_audit_event2) do
            create(:audit_events_project_audit_event, created_at: Time.zone.parse('2024-01-15 05:00:00'))
          end

          let_it_be(:new_group_audit_event2) do
            create(:audit_events_group_audit_event, created_at: Time.zone.parse('2024-01-15 06:00:00'))
          end

          let_it_be(:new_project_audit_event1) do
            create(:audit_events_project_audit_event, created_at: Time.zone.parse('2024-01-15 07:00:00'))
          end

          let_it_be(:new_group_audit_event1) do
            create(:audit_events_group_audit_event, created_at: Time.zone.parse('2024-01-15 08:00:00'))
          end

          let_it_be(:new_user_audit_event) do
            create(:audit_events_user_audit_event, created_at: Time.zone.parse('2024-01-15 09:00:00'))
          end

          let_it_be(:instance_audit_event) do
            create(:audit_events_instance_audit_event, created_at: Time.zone.parse('2024-01-15 10:00:00'))
          end

          describe 'basic functionality' do
            it 'returns 200 response' do
              get api(url, admin, admin_mode: true)

              expect(response).to have_gitlab_http_status(:ok)
            end

            it 'returns all audit events in descending order by default' do
              get api(url, admin, admin_mode: true)

              expected_order = [
                instance_audit_event.id,
                new_user_audit_event.id,
                new_group_audit_event1.id,
                new_project_audit_event1.id,
                new_group_audit_event2.id,
                new_project_audit_event2.id
              ]

              expect(json_response.pluck('id')).to eq(expected_order)
            end
          end

          describe 'pagination' do
            context 'when using cursor pagination' do
              it 'paginates correctly through all pages' do
                get api(url, admin, admin_mode: true), params: { per_page: 2 }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.size).to eq(2)
                expected_page1 = [instance_audit_event.id, new_user_audit_event.id]
                expect(json_response.pluck('id')).to eq(expected_page1)

                expect(response.headers['Link']).to be_present
                expect(response.headers['Link']).to include('rel="next"')

                link_header = response.headers['Link']
                cursor_match = link_header.match(/cursor=([^&>]+)/)
                cursor = CGI.unescape(cursor_match[1])

                get api(url, admin, admin_mode: true), params: { cursor: cursor, per_page: 2 }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.size).to eq(2)
                expected_page2 = [new_group_audit_event1.id, new_project_audit_event1.id]
                expect(json_response.pluck('id')).to eq(expected_page2)

                expect(response.headers['Link']).to be_present
                link_header = response.headers['Link']
                cursor_match = link_header.match(/cursor=([^&>]+)/)
                cursor = CGI.unescape(cursor_match[1])

                get api(url, admin, admin_mode: true), params: { cursor: cursor, per_page: 2 }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.size).to eq(2)
                expected_page3 = [new_group_audit_event2.id, new_project_audit_event2.id]
                expect(json_response.pluck('id')).to eq(expected_page3)

                expect(response.headers['Link']).to be_nil
              end
            end

            context 'when checking cursor behavior with consistent format' do
              it 'uses the same cursor format regardless of feature flag state' do
                stub_feature_flags(read_audit_events_from_new_tables: false)

                base_time = Time.zone.parse('2023-01-20 10:00:00')

                events_data = [
                  { id: 2000, type: :user_audit_event, created_at: base_time - 5.hours },
                  { id: 2001, type: :group_audit_event, created_at: base_time - 4.hours },
                  { id: 2002, type: :instance_audit_event, created_at: base_time - 3.hours },
                  { id: 2003, type: :group_audit_event, created_at: base_time - 2.hours },
                  { id: 2004, type: :project_audit_event, created_at: base_time - 1.hour },
                  { id: 2005, type: :user_audit_event, created_at: base_time }
                ]

                old_events = events_data.map do |data|
                  create(data[:type], id: data[:id], created_at: data[:created_at])
                end

                events_data.each do |data|
                  case data[:type]
                  when :user_audit_event
                    create(:audit_events_user_audit_event,
                      id: data[:id],
                      created_at: data[:created_at],
                      user_id: old_events.find { |e| e.id == data[:id] }.entity_id)
                  when :project_audit_event
                    create(:audit_events_project_audit_event,
                      id: data[:id],
                      created_at: data[:created_at],
                      project_id: old_events.find { |e| e.id == data[:id] }.entity_id)
                  when :group_audit_event
                    create(:audit_events_group_audit_event,
                      id: data[:id],
                      created_at: data[:created_at],
                      group_id: old_events.find { |e| e.id == data[:id] }.entity_id)
                  when :instance_audit_event
                    create(:audit_events_instance_audit_event,
                      id: data[:id],
                      created_at: data[:created_at])
                  end
                end

                get api(url, admin, admin_mode: true), params: {
                  created_before: base_time,
                  pagination: 'keyset',
                  per_page: 3
                }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.size).to eq(3)
                expected_ff_off = [2005, 2004, 2003]
                expect(json_response.pluck('id')).to eq(expected_ff_off)

                cursor_match = response.headers['Link'].match(/cursor=([^>&]+)/)
                cursor_from_old_table = CGI.unescape(cursor_match[1])

                stub_feature_flags(read_audit_events_from_new_tables: true)

                get api(url, admin, admin_mode: true), params: {
                  created_before: base_time,
                  cursor: cursor_from_old_table,
                  per_page: 3
                }

                expect(response).to have_gitlab_http_status(:ok)
                expect(json_response.size).to eq(3)
                expected_ff_on = [2002, 2001, 2000]
                expect(json_response.pluck('id')).to eq(expected_ff_on)
              end
            end
          end

          describe 'filtering' do
            context 'when filtering by entity type' do
              it 'returns only group events' do
                get api(url, admin, admin_mode: true), params: { entity_type: 'Group' }

                expected_group_ids = [new_group_audit_event1.id, new_group_audit_event2.id]
                expect(json_response.pluck('id')).to match_array(expected_group_ids)
                expect(json_response).to all(include('entity_type' => 'Group'))
              end

              it 'returns only project events' do
                get api(url, admin, admin_mode: true), params: { entity_type: 'Project' }

                expected_project_ids = [new_project_audit_event1.id, new_project_audit_event2.id]
                expect(json_response.pluck('id')).to match_array(expected_project_ids)
                expect(json_response).to all(include('entity_type' => 'Project'))
              end

              it 'returns only user events' do
                get api(url, admin, admin_mode: true), params: { entity_type: 'User' }

                expect(json_response.pluck('id')).to contain_exactly(new_user_audit_event.id)
                expect(json_response).to all(include('entity_type' => 'User'))
              end

              it 'returns only instance events' do
                get api(url, admin, admin_mode: true), params: { entity_type: 'Gitlab::Audit::InstanceScope' }

                expect(json_response.pluck('id')).to contain_exactly(instance_audit_event.id)
                expect(json_response).to all(include('entity_type' => 'Gitlab::Audit::InstanceScope'))
              end

              context 'with pagination' do
                it 'paginates filtered results correctly' do
                  get api(url, admin, admin_mode: true), params: { entity_type: 'Group', per_page: 1 }

                  expect(json_response.pluck('id')).to eq([new_group_audit_event1.id])
                  expect(response.headers['Link']).to be_present

                  link_header = response.headers['Link']
                  cursor_match = link_header.match(/cursor=([^&>]+)/)
                  cursor = CGI.unescape(cursor_match[1])

                  get api(url, admin, admin_mode: true), params: { entity_type: 'Group', cursor: cursor, per_page: 1 }

                  expect(json_response.pluck('id')).to eq([new_group_audit_event2.id])
                  expect(response.headers['Link']).to be_nil
                end
              end
            end

            context 'when filtering by date range' do
              it 'returns events within date range' do
                get api(url, admin, admin_mode: true), params: {
                  created_after: Time.zone.parse('2024-01-15 07:00:00'),
                  created_before: Time.zone.parse('2024-01-15 09:00:00')
                }

                expected_date_range_ids = [
                  new_user_audit_event.id,
                  new_group_audit_event1.id,
                  new_project_audit_event1.id
                ]
                expect(json_response.pluck('id')).to match_array(expected_date_range_ids)
              end
            end

            context 'when filtering by author' do
              let_it_be(:author) { create(:user) }
              let_it_be(:authored_event1) do
                create(:audit_events_project_audit_event,
                  author_id: author.id,
                  created_at: Time.zone.parse('2024-01-15 12:00:00'))
              end

              let_it_be(:authored_event2) do
                create(:audit_events_instance_audit_event,
                  author_id: author.id,
                  created_at: Time.zone.parse('2024-01-15 11:00:00'))
              end

              it 'returns events by specific author' do
                get api(url, admin, admin_mode: true), params: { author_id: author.id }

                expected_author_ids = [authored_event1.id, authored_event2.id]
                expect(json_response.pluck('id')).to match_array(expected_author_ids)
              end
            end

            context 'when filtering by entity_id' do
              it 'returns events for specific entity' do
                get api(url, admin, admin_mode: true), params: {
                  entity_type: 'Group',
                  entity_id: new_group_audit_event1.entity_id
                }

                expect(json_response.size).to eq(1)
                expect(json_response.first['id']).to eq(new_group_audit_event1.id)
              end
            end
          end

          describe 'edge cases' do
            it 'returns empty result when no events match filters' do
              get api(url, admin, admin_mode: true), params: {
                entity_type: 'User',
                created_before: Time.zone.parse('2024-01-15 04:00:00')
              }

              expect(json_response).to be_empty
              expect(response.headers['Link']).to be_nil
            end
          end

          describe 'attributes' do
            it 'exposes the right attributes' do
              get api(url, admin, admin_mode: true), params: { entity_type: 'Group' }

              response_item = json_response.first
              details = response_item['details']

              expect(response_item["id"]).to eq(new_group_audit_event1.id)
              expect(response_item["author_id"]).to eq(new_group_audit_event1.user.id)
              expect(response_item["entity_id"]).to eq(new_group_audit_event1.entity_id)
              expect(response_item["entity_type"]).to eq('Group')
              expect(Time.parse(response_item["created_at"])).to be_like_time(new_group_audit_event1.created_at)
              expect(details).to eq new_group_audit_event1.formatted_details.with_indifferent_access
            end
          end

          context 'when both old and new tables have events' do
            it 'only returns events from new tables when feature flag is enabled' do
              get api(url, admin, admin_mode: true), params: { per_page: 20 }

              new_event_ids = [
                instance_audit_event.id,
                new_user_audit_event.id,
                new_group_audit_event1.id,
                new_project_audit_event1.id,
                new_group_audit_event2.id,
                new_project_audit_event2.id
              ]

              returned_ids = json_response.pluck('id')
              expect(returned_ids).to match_array(new_event_ids)
            end
          end
        end
      end
    end
  end

  describe 'GET /audit_events/:id' do
    let_it_be(:user_audit_event) { create(:user_audit_event, created_at: Date.new(2000, 1, 10)) }

    let(:url) { "/audit_events/#{user_audit_event.id}" }

    context 'when authenticated, as a user' do
      let(:user) { create(:user) }

      it_behaves_like '403 response' do
        let(:request) { get api(url, user) }
      end
    end

    context 'when authenticated, as an admin' do
      let(:admin) { create(:admin) }

      context 'audit events feature is not available' do
        it_behaves_like '403 response' do
          let(:request) { get api(url, admin, admin_mode: true) }
        end
      end

      context 'audit events feature is available' do
        before do
          stub_licensed_features(admin_audit_log: true)
          stub_feature_flags(read_audit_events_from_new_tables: false)
        end

        it_behaves_like 'GET request permissions for admin mode' do
          let(:path) { url }
        end

        context 'audit event exists' do
          it 'returns 200 response' do
            get api(url, admin, admin_mode: true)

            expect(response).to have_gitlab_http_status(:ok)
          end

          context 'attributes' do
            it 'exposes the right attributes' do
              get api(url, admin, admin_mode: true)
              details = json_response['details']

              expect(json_response["id"]).to eq(user_audit_event.id)
              expect(json_response["author_id"]).to eq(user_audit_event.user.id)
              expect(json_response["entity_id"]).to eq(user_audit_event.entity_id)
              expect(json_response["entity_type"]).to eq('User')
              expect(Time.parse(json_response["created_at"])).to be_like_time(user_audit_event.created_at)
              expect(details).to eq user_audit_event.formatted_details.with_indifferent_access
            end
          end
        end

        context 'audit event does not exist' do
          it_behaves_like '404 response' do
            let(:url) { "/audit_events/10001" }
            let(:request) { get api(url, admin, admin_mode: true) }
          end
        end

        context 'with new audit tables (feature flag enabled)' do
          before do
            stub_feature_flags(read_audit_events_from_new_tables: true)
          end

          let_it_be(:new_user_audit_event) { create(:audit_events_user_audit_event) }
          let_it_be(:new_project_audit_event) { create(:audit_events_project_audit_event) }
          let_it_be(:new_group_audit_event) { create(:audit_events_group_audit_event) }
          let_it_be(:new_instance_audit_event) { create(:audit_events_instance_audit_event) }

          describe '#find' do
            context 'when audit event exists' do
              context 'with instance audit event' do
                let(:url) { "/audit_events/#{new_instance_audit_event.id}" }

                it 'returns the correct audit event' do
                  get api(url, admin, admin_mode: true)

                  expect(response).to have_gitlab_http_status(:ok)
                  expect(json_response["id"]).to eq(new_instance_audit_event.id)
                  expect(json_response["entity_type"]).to eq('Gitlab::Audit::InstanceScope')
                end
              end

              context 'with user audit event' do
                let(:url) { "/audit_events/#{new_user_audit_event.id}" }

                it 'returns the correct audit event' do
                  get api(url, admin, admin_mode: true)

                  expect(response).to have_gitlab_http_status(:ok)
                  expect(json_response["id"]).to eq(new_user_audit_event.id)
                  expect(json_response["entity_type"]).to eq('User')
                end
              end

              context 'with group audit event' do
                let(:url) { "/audit_events/#{new_group_audit_event.id}" }

                it 'returns the correct audit event' do
                  get api(url, admin, admin_mode: true)

                  expect(response).to have_gitlab_http_status(:ok)
                  expect(json_response["id"]).to eq(new_group_audit_event.id)
                  expect(json_response["entity_type"]).to eq('Group')
                end
              end

              context 'with project audit event' do
                let(:url) { "/audit_events/#{new_project_audit_event.id}" }

                it 'returns the correct audit event' do
                  get api(url, admin, admin_mode: true)

                  expect(response).to have_gitlab_http_status(:ok)
                  expect(json_response["id"]).to eq(new_project_audit_event.id)
                  expect(json_response["entity_type"]).to eq('Project')
                end
              end
            end

            context 'when audit event does not exist' do
              let(:url) { "/audit_events/999999" }

              it 'raises ActiveRecord::RecordNotFound' do
                get api(url, admin, admin_mode: true)

                expect(response).to have_gitlab_http_status(:not_found)
              end
            end
          end

          describe 'attributes' do
            let(:url) { "/audit_events/#{new_group_audit_event.id}" }

            it 'exposes the right attributes' do
              get api(url, admin, admin_mode: true)
              details = json_response['details']

              expect(json_response["id"]).to eq(new_group_audit_event.id)
              expect(json_response["author_id"]).to eq(new_group_audit_event.user.id)
              expect(json_response["entity_id"]).to eq(new_group_audit_event.entity_id)
              expect(json_response["entity_type"]).to eq('Group')
              expect(Time.parse(json_response["created_at"])).to be_like_time(new_group_audit_event.created_at)
              expect(details).to eq new_group_audit_event.formatted_details.with_indifferent_access
            end
          end
        end
      end
    end
  end
end
