# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Members::AddedService, :clean_gitlab_redis_shared_state, feature_category: :seat_cost_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }

  describe '#execute' do
    let(:invited_user_ids) { [non_existing_record_id, nil, user.id] }
    let(:instance) { described_class.new(source, invited_user_ids) }

    subject(:execute) { instance.execute }

    describe 'with valid params' do
      let(:source) { create(:group, parent: namespace) }

      it 'create a new seat assignment record' do
        source.add_developer(user)

        expect do
          expect(execute).to be_success
        end.to change { GitlabSubscriptions::SeatAssignment.where(user: user, namespace: namespace).count }
          .by(1)
      end

      it 'does not create new seat_assignment record, if one already exists' do
        create(:gitlab_subscription_seat_assignment, namespace: namespace, user: user)

        expect do
          expect(execute).to be_success
        end.not_to change { GitlabSubscriptions::SeatAssignment.count }
      end

      context "when source is of type 'Project'" do
        let(:source) { build(:project, namespace: namespace) }

        it 'creates new seat assignment record' do
          source.add_developer(user)

          expect do
            expect(execute).to be_success
          end.to change { GitlabSubscriptions::SeatAssignment.where(user: user, namespace: namespace).count }.by(1)
        end
      end
    end

    context 'with invalid params' do
      context 'when source is nil' do
        let(:source) { nil }

        it 'returns an error' do
          response = execute

          expect(response).to be_error
          expect(response.message).to eq('Invalid params')
        end
      end

      context 'when source does not have root_ancestor' do
        let(:source) { instance_double(::Group) }

        before do
          allow(source).to receive(:root_ancestor).and_return(nil)
        end

        it 'returns an error' do
          response = execute

          expect(response).to be_error
          expect(response.message).to eq('Invalid params')
        end
      end
    end
  end
end
