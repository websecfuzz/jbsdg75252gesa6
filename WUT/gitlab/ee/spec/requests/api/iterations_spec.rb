# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Iterations, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:parent_group) { create(:group, :private) }
  let_it_be(:group) { create(:group, :private, parent: parent_group) }
  let_it_be(:subgroup) { create(:group, :private, parent: group) }

  let_it_be(:current_iteration) do
    create(
      :iteration,
      group: group,
      title: 'search_title',
      start_date: 5.days.ago,
      due_date: 1.week.from_now,
      updated_at: 1.day.ago
    )
  end

  let_it_be(:closed_iteration) do
    create(:iteration, group: group, start_date: 2.weeks.ago, due_date: 1.week.ago, updated_at: 5.days.ago)
  end

  let_it_be(:ancestor_iteration) do
    create(:iteration, :with_due_date, group: parent_group, start_date: 2.weeks.from_now, updated_at: 10.days.ago)
  end

  let_it_be(:descendant_iteration) do
    create(:iteration, :with_due_date, group: subgroup, start_date: 2.weeks.from_now, updated_at: 10.days.ago)
  end

  before_all do
    current_iteration.iterations_cadence.update!(title: "abc")
    parent_group.add_guest(user)
  end

  shared_examples 'iterations list' do
    context 'when user does not have access' do
      it 'returns 404' do
        get api(api_path, nil)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user has access' do
      it 'returns a list of iterations', :aggregate_failures do
        get api(api_path, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(3)
        expect(json_response.map { |i| i['id'] }).to contain_exactly(current_iteration.id, closed_iteration.id, ancestor_iteration.id)
        expect(json_response.map { |i| i['sequence'] }).to contain_exactly(current_iteration.sequence, closed_iteration.sequence, ancestor_iteration.sequence)
      end

      context 'filter by iteration state' do
        it 'returns `closed` state iterations' do
          get api(api_path, user), params: { state: 'closed' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(1)
          expect(json_response.first['id']).to eq(closed_iteration.id)
        end

        # to be removed when `started` state DEPRECATION is removed in new REST API version.
        # May take a while as there is no planned date for next REST API version
        it 'returns current iteration' do
          get api(api_path, user), params: { state: 'started' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(1)
          expect(json_response.first['id']).to eq(current_iteration.id)
          expect(json_response.first['state']).to eq(Iteration::STATE_ENUM_MAP[:current])
        end

        it 'returns `current` state iterations' do
          get api(api_path, user), params: { state: 'current' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(1)
          expect(json_response.first['id']).to eq(current_iteration.id)
        end
      end

      context 'filter by updated_at' do
        it 'returns iterations filtered only by updated_before' do
          get api(api_path, user), params: { updated_before: 3.days.ago.iso8601 }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(2)
          expect(json_response).to contain_exactly(
            hash_including('id' => closed_iteration.id),
            hash_including('id' => ancestor_iteration.id)
          )
        end

        it 'returns iterations filtered only by updated_after' do
          get api(api_path, user), params: { updated_after: 7.days.ago.iso8601 }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(2)
          expect(json_response).to contain_exactly(
            hash_including('id' => closed_iteration.id),
            hash_including('id' => current_iteration.id)
          )
        end

        it 'returns iterations filtered by updated_after and updated_before' do
          get api(api_path, user), params: { updated_after: 7.days.ago.iso8601, updated_before: 3.days.ago }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.size).to eq(1)
          expect(json_response).to contain_exactly(hash_including('id' => closed_iteration.id))
        end
      end

      it 'returns iterations filtered by title' do
        get api(api_path, user), params: { search: 'search_' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(1)
        expect(json_response.first['id']).to eq(current_iteration.id)
      end

      it 'returns iterations filtered by title with `in` parameter' do
        get api(api_path, user), params: { search: 'search_', in: %w[title] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(1)
        expect(json_response.first['id']).to eq(current_iteration.id)
      end

      it 'returns iterations filtered by cadence title' do
        get api(api_path, user), params: { search: 'abc', in: %w[cadence_title] }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.size).to eq(1)
        expect(json_response.first['id']).to eq(current_iteration.id)
      end

      it 'returns 400 when `in` param is invalid' do
        get api(api_path, user), params: { search: 'search_', in: %w[foobar] }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when `state` param is invalid' do
        get api(api_path, user), params: { state: 'non-existent-state' }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end

  describe 'GET /groups/:id/iterations' do
    let(:api_path) { "/groups/#{group.id}/iterations" }

    it_behaves_like 'iterations list'

    it 'excludes ancestor iterations when include_ancestors is set to false' do
      get api(api_path, user), params: { include_ancestors: false }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.size).to eq(2)
      expect(json_response.map { |i| i['id'] }).to contain_exactly(current_iteration.id, closed_iteration.id)
    end

    it 'includes descendant iterations when include_descendants is set to true' do
      get api(api_path, user), params: { include_ancestors: false, include_descendants: true }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.size).to eq(3)
      expect(json_response.map { |i| i['id'] }).to contain_exactly(current_iteration.id, closed_iteration.id, descendant_iteration.id)
    end
  end

  describe 'GET /projects/:id/iterations' do
    let_it_be(:project) { create(:project, :private, group: group) }

    let(:api_path) { "/projects/#{project.id}/iterations" }

    it_behaves_like 'iterations list'

    it 'excludes ancestor iterations of direct parent group when include_ancestors is set to false' do
      get api(api_path, user), params: { include_ancestors: false }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.map { |i| i['id'] }).to contain_exactly(current_iteration.id, closed_iteration.id)
    end

    it 'includes descendant iterations of direct parent group when include_descendants is set to true' do
      get api(api_path, user), params: { include_ancestors: false, include_descendants: true }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.map { |i| i['id'] }).to contain_exactly(current_iteration.id, closed_iteration.id, descendant_iteration.id)
    end
  end
end
