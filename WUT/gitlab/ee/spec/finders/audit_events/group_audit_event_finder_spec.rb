# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::GroupAuditEventFinder, feature_category: :audit_events do
  let_it_be(:user_1) { create(:user) }
  let_it_be(:user_2) { create(:user) }
  let_it_be(:user_3) { create(:user) }
  let_it_be(:group_1) { create(:group) }
  let_it_be(:group_2) { create(:group) }

  let_it_be(:group_audit_event_1) do
    create(:audit_events_group_audit_event, group_id: group_1.id, author_id: user_1.id, created_at: 2.days.ago)
  end

  let_it_be(:group_audit_event_2) do
    create(:audit_events_group_audit_event, group_id: group_1.id, author_id: user_2.id, created_at: 4.days.ago)
  end

  let_it_be(:group_audit_event_3) do
    create(:audit_events_group_audit_event, group_id: group_2.id, author_id: user_2.id, created_at: 4.days.ago)
  end

  let_it_be(:group_audit_event_4) do
    create(:audit_events_group_audit_event, group_id: group_2.id, author_id: user_3.id, created_at: 4.days.ago)
  end

  let(:params) { {} }

  subject(:finder) { described_class.new(group: group_1, params: params) }

  describe '#execute' do
    subject(:execute) { finder.execute }

    shared_examples 'no filtering' do
      it 'finds all group events' do
        expect(execute).to contain_exactly(group_audit_event_1, group_audit_event_2)
      end
    end

    context 'when filtering by author_id' do
      context 'when invalid author_id is passed' do
        let(:params) { { author_id: '0' } }

        it_behaves_like 'no filtering'
      end

      context 'when author_id is passed' do
        let(:params) { { author_id: user_2.id } }

        it 'finds the right event' do
          expect(execute).to contain_exactly(group_audit_event_2)
        end
      end
    end

    context 'when filtering by created_at' do
      context 'when filtering by created_after' do
        let(:params) { { created_after: group_audit_event_1.created_at } }

        it 'returns events created on or after the given date' do
          expect(execute).to contain_exactly(group_audit_event_1)
        end
      end

      context 'when filtering by created_before' do
        let(:params) { { created_before: group_audit_event_2.created_at } }

        it 'returns events created on or before the given date' do
          expect(execute).to contain_exactly(group_audit_event_2)
        end
      end

      context 'when both created_after and created_before are passed' do
        let(:params) do
          { created_after: group_audit_event_2.created_at, created_before: group_audit_event_1.created_at }
        end

        it 'returns events created between the given dates' do
          expect(execute).to contain_exactly(group_audit_event_2, group_audit_event_1)
        end
      end
    end

    context 'when filtering by author_username' do
      context 'when username is too short' do
        let(:params) { { author_username: 'a' * (User::MIN_USERNAME_LENGTH - 1) } }

        it 'ignores author_username and returns all events' do
          expect(execute).to contain_exactly(group_audit_event_2, group_audit_event_1)
        end
      end

      context 'when username is too long' do
        let(:params) { { author_username: 'a' * (User::MAX_USERNAME_LENGTH + 1) } }

        it 'ignores author_username and returns all events' do
          expect(execute).to contain_exactly(group_audit_event_2, group_audit_event_1)
        end
      end

      context 'when username is of right length' do
        context 'when username does not exist' do
          let(:params) { { author_username: 'a' * User::MAX_USERNAME_LENGTH } }

          it 'ignores author_username and returns all events' do
            expect(execute).to be_empty
          end
        end

        context 'when username does exist' do
          context 'when events belonging to user are of group passed' do
            let(:params) { { author_username: user_1.username } }

            it 'returns events belonging to user' do
              expect(execute).to contain_exactly(group_audit_event_1)
            end
          end

          context 'when events belonging to user are of different group' do
            let(:params) { { author_username: user_3.username } }

            it 'does not return any event' do
              expect(execute).to be_empty
            end
          end
        end
      end
    end

    context 'when sort param is passed' do
      context 'when created_asc is passed' do
        let(:params) { { sort: 'created_asc' } }

        it 'returns group audit events in asc order' do
          expect(execute).to eq([group_audit_event_1, group_audit_event_2])
        end
      end

      context 'when created_desc is passed' do
        let(:params) { { sort: 'created_desc' } }

        it 'returns group audit events in desc order' do
          expect(execute).to eq([group_audit_event_2, group_audit_event_1])
        end
      end
    end
  end

  describe '#find_by!' do
    let(:id) { group_audit_event_1.id }

    subject(:find) { finder.find_by!(id: id) } # rubocop:disable Rails/FindById -- Not ActiveRecord find_by!

    it { is_expected.to eq(group_audit_event_1) }

    context 'when non-existent id provided' do
      let(:id) { 'non-existent-id' }

      it 'raises exception' do
        expect { find }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'offset optimization' do
    let_it_be(:pagination_events) do
      create_list(:audit_events_group_audit_event, 5, group_id: group_1.id, created_at: 3.days.ago)
    end

    after do
      pagination_events.each(&:destroy)
    end

    context 'with keyset pagination' do
      let(:params) { { page: 101, per_page: 1, pagination: 'keyset', optimize_offset: true } }

      it 'does not use optimization' do
        expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan).not_to receive(:new)

        finder.execute
      end
    end

    context 'with high page numbers' do
      let(:params) { { page: 101, per_page: 10, optimize_offset: true } }

      it 'uses optimization' do
        expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
          .to receive(:new)
          .with(hash_including(
            page: 101,
            per_page: 10,
            scope: kind_of(ActiveRecord::Relation)
          ))
          .and_call_original

        finder.execute
      end
    end

    context 'with filters' do
      let(:base_params) { { page: 101, per_page: 10, optimize_offset: true } }

      context 'with created_after filter' do
        let(:params) { base_params.merge(created_after: group_audit_event_1.created_at) }

        it 'uses optimization and returns correct results' do
          expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
            .to receive(:new)
            .with(hash_including(page: 101, per_page: 10))
            .and_call_original

          results = finder.execute

          expect(results).to all(have_attributes(created_at: be >= group_audit_event_1.created_at))
        end
      end

      context 'with author_id filter' do
        let(:params) { base_params.merge(author_id: user_1.id) }

        it 'uses optimization and returns correct results' do
          expect(Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan)
            .to receive(:new)
            .with(hash_including(page: 101, per_page: 10))
            .and_call_original

          results = finder.execute

          expect(results).to all(have_attributes(author_id: user_1.id))
        end
      end
    end
  end
end
