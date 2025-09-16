# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::CombinedAuditEventFinder, feature_category: :audit_events do
  let(:finder) { described_class.new(params: params) }
  let(:params) { { per_page: 20 } }

  let(:base_time) { Time.zone.parse('2024-01-15 12:00:00') }

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be(:author) { create(:user) }

  let_it_be(:instance_event1) do
    create(:audit_events_instance_audit_event, created_at: Time.zone.parse('2024-01-15 06:00:00'), author_id: author.id)
  end

  let_it_be(:user_event1) do
    create(:audit_events_user_audit_event, created_at: Time.zone.parse('2024-01-15 07:00:00'), user_id: user.id)
  end

  let_it_be(:group_event1) do
    create(:audit_events_group_audit_event, created_at: Time.zone.parse('2024-01-15 08:00:00'), group_id: group.id)
  end

  let_it_be(:project_event1) do
    create(:audit_events_project_audit_event, created_at: Time.zone.parse('2024-01-15 09:00:00'),
      project_id: project.id)
  end

  let_it_be(:group_event2) do
    create(:audit_events_group_audit_event, created_at: Time.zone.parse('2024-01-15 10:00:00'), group_id: group.id)
  end

  let_it_be(:project_event2) do
    create(:audit_events_project_audit_event,
      created_at: Time.zone.parse('2024-01-15 11:00:00'),
      project_id: project.id,
      author_id: author.id)
  end

  describe '#find' do
    subject(:find) { finder.find(id) }

    context 'when audit event exists' do
      context 'with instance audit event' do
        let(:id) { instance_event1.id }

        it 'returns the correct audit event' do
          expect(find).to eq(instance_event1)
          expect(find).to be_a(AuditEvents::InstanceAuditEvent)
        end
      end

      context 'with user audit event' do
        let(:id) { user_event1.id }

        it 'returns the correct audit event' do
          expect(find).to eq(user_event1)
          expect(find).to be_a(AuditEvents::UserAuditEvent)
        end
      end

      context 'with group audit event' do
        let(:id) { group_event1.id }

        it 'returns the correct audit event' do
          expect(find).to eq(group_event1)
          expect(find).to be_a(AuditEvents::GroupAuditEvent)
        end
      end

      context 'with project audit event' do
        let(:id) { project_event1.id }

        it 'returns the correct audit event' do
          expect(find).to eq(project_event1)
          expect(find).to be_a(AuditEvents::ProjectAuditEvent)
        end
      end
    end

    context 'when audit event does not exist' do
      let(:id) { non_existing_record_id }

      it 'raises ActiveRecord::RecordNotFound' do
        expect { find }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe '#execute' do
    subject(:execute) { finder.execute }

    context 'when testing basic functionality' do
      it 'returns all audit events in descending order by created_at' do
        result = execute

        expect(result[:records]).to eq([
          project_event2,
          group_event2,
          project_event1,
          group_event1,
          user_event1,
          instance_event1
        ])
      end

      it 'returns keyset pagination metadata' do
        result = execute

        expect(result).to have_key(:records)
        expect(result).to have_key(:cursor_for_next_page)
        expect(result[:records]).to be_an(Array)
      end
    end

    context 'when SimpleOrderBuilder returns failure' do
      before do
        allow(Gitlab::Pagination::Keyset::SimpleOrderBuilder)
          .to receive(:build)
                .and_return([nil, false])
      end

      it 'raises an error' do
        expect { execute }
          .to raise_error(RuntimeError, 'Failed to build keyset ordering')
      end
    end

    context 'when using pagination' do
      let(:params) { { per_page: 1 } }

      it 'paginates correctly through all pages' do
        page1 = described_class.new(params: params).execute
        expect(page1[:records]).to eq([project_event2])
        expect(page1[:cursor_for_next_page]).to be_present

        page2 = described_class.new(params: params.merge(cursor: page1[:cursor_for_next_page])).execute
        expect(page2[:records]).to eq([group_event2])
        expect(page2[:cursor_for_next_page]).to be_present

        page3 = described_class.new(params: params.merge(cursor: page2[:cursor_for_next_page])).execute
        expect(page3[:records]).to eq([project_event1])
        expect(page3[:cursor_for_next_page]).to be_present

        page4 = described_class.new(params: params.merge(cursor: page3[:cursor_for_next_page])).execute
        expect(page4[:records]).to eq([group_event1])
        expect(page4[:cursor_for_next_page]).to be_present

        page5 = described_class.new(params: params.merge(cursor: page4[:cursor_for_next_page])).execute
        expect(page5[:records]).to eq([user_event1])
        expect(page5[:cursor_for_next_page]).to be_present

        page6 = described_class.new(params: params.merge(cursor: page5[:cursor_for_next_page])).execute
        expect(page6[:records]).to eq([instance_event1])
        expect(page6[:cursor_for_next_page]).to be_nil
      end
    end

    context 'when filtering records' do
      context 'when filtering by entity type' do
        let(:params) { { entity_type: 'Group', per_page: 20 } }

        it 'returns only group events in descending order' do
          result = execute

          expect(result[:records]).to eq([group_event2, group_event1])
          expect(result[:records]).to all(be_a(AuditEvents::GroupAuditEvent))
        end

        context 'with pagination' do
          let(:params) { { entity_type: 'Group', per_page: 1 } }

          it 'paginates filtered results correctly' do
            page1 = execute
            expect(page1[:records]).to eq([group_event2])
            expect(page1[:cursor_for_next_page]).to be_present

            page2 = described_class.new(params: params.merge(cursor: page1[:cursor_for_next_page])).execute
            expect(page2[:records]).to eq([group_event1])
            expect(page2[:cursor_for_next_page]).to be_nil
          end
        end

        context 'with project entity type' do
          let(:params) { { entity_type: 'Project', per_page: 20 } }

          it 'returns only project events' do
            result = execute

            expect(result[:records]).to eq([project_event2, project_event1])
            expect(result[:records]).to all(be_a(AuditEvents::ProjectAuditEvent))
          end
        end

        context 'with user entity type' do
          let(:params) { { entity_type: 'User', per_page: 20 } }

          it 'returns only user events' do
            result = execute

            expect(result[:records]).to eq([user_event1])
            expect(result[:records]).to all(be_a(AuditEvents::UserAuditEvent))
          end
        end

        context 'with instance entity type' do
          let(:params) { { entity_type: 'Gitlab::Audit::InstanceScope', per_page: 20 } }

          it 'returns only instance events' do
            result = execute

            expect(result[:records]).to eq([instance_event1])
            expect(result[:records]).to all(be_a(AuditEvents::InstanceAuditEvent))
          end
        end
      end

      context 'when filtering by entity_id' do
        context 'with valid entity_type and entity_id' do
          context 'for Group entity' do
            let(:params) { { entity_type: 'Group', entity_id: group.id, per_page: 20 } }

            it 'returns only events for the specific group' do
              result = execute

              expect(result[:records]).to eq([group_event2, group_event1])
              expect(result[:records]).to all(have_attributes(group_id: group.id))
            end
          end

          context 'for Project entity' do
            let(:params) { { entity_type: 'Project', entity_id: project.id, per_page: 20 } }

            it 'returns only events for the specific project' do
              result = execute

              expect(result[:records]).to eq([project_event2, project_event1])
              expect(result[:records]).to all(have_attributes(project_id: project.id))
            end
          end

          context 'for User entity' do
            let(:params) { { entity_type: 'User', entity_id: user.id, per_page: 20 } }

            it 'returns only events for the specific user' do
              result = execute

              expect(result[:records]).to eq([user_event1])
              expect(result[:records]).to all(have_attributes(user_id: user.id))
            end
          end

          context 'when entity_id does not exist' do
            let(:params) { { entity_type: 'Group', entity_id: non_existing_record_id, per_page: 20 } }

            it 'returns empty results' do
              result = execute

              expect(result[:records]).to be_empty
              expect(result[:cursor_for_next_page]).to be_nil
            end
          end
        end

        context 'when entity_id is provided without entity_type' do
          let(:params) { { entity_id: group.id, per_page: 20 } }

          it 'ignores entity_id and returns all events' do
            result = execute

            expect(result[:records]).to eq([
              project_event2,
              group_event2,
              project_event1,
              group_event1,
              user_event1,
              instance_event1
            ])
          end
        end
      end

      context 'when filtering by date range' do
        let(:params) do
          { created_after: Time.zone.parse('2024-01-15 09:00:00'),
            created_before: Time.zone.parse('2024-01-15 11:00:00'), per_page: 20 }
        end

        it 'returns events within date range in descending order' do
          result = execute

          expect(result[:records]).to eq([project_event2, group_event2, project_event1])
        end
      end

      context 'when filtering by author' do
        let(:params) { { author_id: author.id, per_page: 20 } }

        it 'returns events by specific author in descending order' do
          result = execute

          expect(result[:records]).to eq([project_event2, instance_event1])
        end
      end
    end

    context 'when using combined filters with pagination' do
      let_it_be(:another_group) { create(:group) }
      let_it_be(:another_project) { create(:project) }

      let_it_be(:another_group_event1) do
        create(:audit_events_group_audit_event,
          created_at: Time.zone.parse('2024-01-15 09:30:00'),
          group_id: another_group.id)
      end

      let_it_be(:another_group_event2) do
        create(:audit_events_group_audit_event,
          created_at: Time.zone.parse('2024-01-15 10:30:00'),
          group_id: another_group.id)
      end

      let_it_be(:another_project_event) do
        create(:audit_events_project_audit_event,
          created_at: Time.zone.parse('2024-01-15 09:45:00'),
          project_id: another_project.id,
          author_id: author.id)
      end

      context 'with entity_type and entity_id' do
        let(:params) { { entity_type: 'Group', entity_id: group.id, per_page: 1 } }

        it 'applies both entity type and entity_id filters with pagination correctly' do
          page1 = execute
          expect(page1[:records]).to eq([group_event2])
          expect(page1[:records].first.group_id).to eq(group.id)
          expect(page1[:cursor_for_next_page]).to be_present

          page2 = described_class.new(params: params.merge(cursor: page1[:cursor_for_next_page])).execute
          expect(page2[:records]).to eq([group_event1])
          expect(page2[:records].first.group_id).to eq(group.id)
          expect(page2[:cursor_for_next_page]).to be_nil

          all_pages = [page1[:records], page2[:records]].flatten
          expect(all_pages).not_to include(another_group_event1, another_group_event2)
        end
      end

      context 'with date range, entity type, and entity_id' do
        let(:params) do
          {
            entity_type: 'Project',
            entity_id: project.id,
            created_after: Time.zone.parse('2024-01-15 09:00:00'),
            per_page: 1
          }
        end

        it 'applies all three filters correctly' do
          page1 = execute
          expect(page1[:records]).to eq([project_event2])
          expect(page1[:records].first.project_id).to eq(project.id)
          expect(page1[:cursor_for_next_page]).to be_present

          page2 = described_class.new(params: params.merge(cursor: page1[:cursor_for_next_page])).execute
          expect(page2[:records]).to eq([project_event1])
          expect(page2[:records].first.project_id).to eq(project.id)
          expect(page2[:cursor_for_next_page]).to be_nil

          expect(page1[:records]).not_to include(another_project_event)
          expect(page2[:records]).not_to include(another_project_event)
        end
      end

      context 'with author_id, entity_type, and entity_id' do
        let(:params) do
          {
            entity_type: 'Project',
            entity_id: project.id,
            author_id: author.id,
            per_page: 1
          }
        end

        it 'filters by all criteria including author' do
          result = execute
          expect(result[:records]).to eq([project_event2])
          expect(result[:records].first).to have_attributes(
            project_id: project.id,
            author_id: author.id
          )
          expect(result[:cursor_for_next_page]).to be_nil

          expect(result[:records]).not_to include(project_event1)
        end
      end

      context 'with entity_id for non-existent entity' do
        let(:params) do
          {
            entity_type: 'Group',
            entity_id: non_existing_record_id,
            per_page: 2
          }
        end

        it 'returns empty result when entity_id does not match any records' do
          result = execute

          expect(result[:records]).to be_empty
          expect(result[:cursor_for_next_page]).to be_nil
        end
      end

      context 'with all filters combined' do
        let(:params) do
          {
            entity_type: 'Group',
            entity_id: another_group.id,
            created_after: Time.zone.parse('2024-01-15 09:00:00'),
            created_before: Time.zone.parse('2024-01-15 10:00:00'),
            per_page: 1
          }
        end

        it 'correctly applies all filters with pagination' do
          page1 = execute
          expect(page1[:records]).to eq([another_group_event1])
          expect(page1[:records].first.group_id).to eq(another_group.id)
          expect(page1[:cursor_for_next_page]).to be_nil

          # another_group_event2 is outside the date range
          expect(page1[:records]).not_to include(another_group_event2)
        end
      end

      it 'returns empty result when no events match all combined filters' do
        result = described_class.new(params: {
          entity_type: 'User',
          entity_id: user.id,
          created_before: Time.zone.parse('2024-01-15 06:00:00'),
          per_page: 2
        }).execute

        expect(result[:records]).to be_empty
        expect(result[:cursor_for_next_page]).to be_nil
      end
    end
  end
end
