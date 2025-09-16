# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::MergeRequestDependencies, 'MergeRequestDependencies', feature_category: :code_review_workflow do
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:other_project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, :unique_branches, source_project: project, author: maintainer) }
  let_it_be(:other_merge_request) do
    create(:merge_request, :unique_branches, source_project: project, author: maintainer)
  end

  let_it_be(:another_merge_request) do
    create(:merge_request, :unique_branches, source_project: project, author: maintainer)
  end

  let_it_be(:private_merge_request_1) do
    create(:merge_request, :unique_branches, source_project: other_project, author: maintainer)
  end

  let_it_be(:private_merge_request_2) do
    create(:merge_request, :unique_branches, source_project: other_project, author: guest)
  end

  let_it_be(:block_1) { merge_request.blocks_as_blockee.create!(blocking_merge_request: other_merge_request) }
  let_it_be(:block_2) { merge_request.blocks_as_blockee.create!(blocking_merge_request: another_merge_request) }
  let_it_be(:private_block_1) do
    private_merge_request_1.blocks_as_blockee.create!(blocking_merge_request: other_merge_request)
  end

  let_it_be(:private_block_2) do
    private_merge_request_2.blocks_as_blockee.create!(blocking_merge_request: other_merge_request)
  end

  before_all do
    project.add_maintainer(maintainer)
    project.add_guest(guest)
    other_project.add_guest(maintainer)
    other_project.add_guest(guest)
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/blocks' do
    let_it_be(:block_3) { merge_request.blocks_as_blockee.create!(blocking_merge_request: private_merge_request_1) }
    let_it_be(:block_4) { merge_request.blocks_as_blockee.create!(blocking_merge_request: private_merge_request_2) }

    it 'returns 200 for a valid merge request' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks", maintainer)

      aggregate_failures('response') do
        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
      end

      aggregate_failures('json_response') do
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(merge_request.blocks_as_blockee.size)
        expect(json_response.first['id']).to eq(block_1.id)
        expect(json_response.first.dig('blocking_merge_request', 'id'))
          .to eq(block_1.blocking_merge_request.id)
        expect(json_response.first.dig('blocked_merge_request', 'id'))
          .to eq(block_1.blocked_merge_request.id)

        expect(json_response.find { |block| block['id'] == block_1.id }).to include('blocking_merge_request')
        expect(json_response.find { |block| block['id'] == block_2.id }).to include('blocking_merge_request')
        expect(json_response.find { |block| block['id'] == block_3.id }).not_to include('blocking_merge_request')
        expect(json_response.find { |block| block['id'] == block_4.id }).not_to include('blocking_merge_request')
      end
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/blocks", maintainer)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:user) { guest }
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks" }
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/blocks/:block_id' do
    it 'returns a 200 for a valid merge request' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks/#{block_1.id}", maintainer)

      expect(response).to have_gitlab_http_status(:ok)

      aggregate_failures('json_response') do
        expect(json_response['id']).to eq(block_1.id)
        expect(json_response.dig('blocking_merge_request', 'id'))
          .to eq(block_1.blocking_merge_request.id)
        expect(json_response.dig('blocked_merge_request', 'id'))
          .to eq(block_1.blocked_merge_request.id)
      end
    end

    context 'when the user does not have read permissions for the blocking MR' do
      let!(:block_3) { merge_request.blocks_as_blockee.create!(blocking_merge_request: private_merge_request_1) }

      it 'does not contain information about the blocking merge request' do
        get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks/#{block_3.id}", maintainer)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to include('blocking_merge_request')
      end
    end

    it 'returns a 404 when merge_request block id is not found' do
      get api("/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks/0", maintainer)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns a 404 when merge_request_iid is not found' do
      get api("/projects/#{project.id}/merge_requests/#{non_existing_record_iid}/blocks/#{block_1.id}", maintainer)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when the user does not have read permissions for the MR' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:user) { guest }
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/blocks/#{block_1.id}" }
      end
    end
  end

  describe 'DELETE /projects/:id/merge_requests/:merge_request_iid/blocks/:block_id' do
    let(:merge_request_iid) { merge_request.iid }
    let(:block_id) { block_1.id }
    let(:user) { maintainer }

    let(:request) do
      delete api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/blocks/#{block_id}", user)
    end

    it 'returns 204 for a valid merge request' do
      request

      aggregate_failures('response') do
        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    context 'when the block id is invalid' do
      let(:block_id) { non_existing_record_id }

      it 'returns a 404 when block is not found' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when the merge request iid is invalid' do
      let(:merge_request_iid) { non_existing_record_iid }

      it 'returns a 404 when merge_request is not found' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when user can not read the blocking merge request' do
      let(:block_3) { merge_request.blocks_as_blockee.create!(blocking_merge_request: private_merge_request_1) }
      let(:block_id) { block_3.id }
      let(:user) { guest }

      it 'returns a 403 error' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('403 Forbidden')
      end
    end

    context 'when user can not update the merge request' do
      let(:user) { guest }

      it 'returns a 403 error' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('403 Forbidden')
      end
    end
  end

  describe 'POST /projects/:id/merge_requests/:merge_request_iid/blocks' do
    let(:merge_request_iid) { merge_request.iid }
    let(:extra_merge_request) { create(:merge_request, :unique_branches, source_project: project, author: user) }
    let(:user) { maintainer }

    let(:request) do
      post api("/projects/#{project.id}/merge_requests/#{merge_request_iid}/blocks", user), params:
        { blocking_merge_request_id: extra_merge_request.id }
    end

    it 'returns 201 for a valid merge request' do
      request

      new_blockee = MergeRequestBlock.last

      aggregate_failures('response') do
        expect(response).to have_gitlab_http_status(:created)
      end

      aggregate_failures('json_response') do
        expect(json_response['id']).to eq(new_blockee.id)
        expect(json_response.dig('blocking_merge_request', 'id'))
          .to eq(new_blockee.blocking_merge_request.id)
        expect(json_response.dig('blocked_merge_request', 'id'))
          .to eq(new_blockee.blocked_merge_request.id)
      end
    end

    context 'when the merge request iid is invalid' do
      let(:merge_request_iid) { non_existing_record_iid }

      it 'returns a 404 when merge_request is not found' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when merge request is already blocking' do
      it 'returns a 400 error' do
        ::MergeRequestBlock.create!(
          blocking_merge_request_id: extra_merge_request.id,
          blocked_merge_request_id: merge_request.id
        )

        request

        expect(response).to have_gitlab_http_status(:conflict)
        expect(json_response['message']).to eq('Block already exists')
      end
    end

    context 'when user can not read the blocking merge request' do
      let(:other_project_merge_request) do
        create(:merge_request, :unique_branches, source_project: other_project)
      end

      let(:user) { maintainer }
      let(:extra_merge_request) { other_project_merge_request }

      it 'returns a 403 error' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('Lacking permissions to the blocking merge request')
      end
    end

    context 'when merge request author has only guest access' do
      let(:user) { guest }

      it 'returns a 404 error' do
        request

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Not found')
      end
    end
  end

  describe 'GET /projects/:id/merge_requests/:merge_request_iid/blockees' do
    it 'returns 200 for a valid merge request' do
      get api("/projects/#{project.id}/merge_requests/#{other_merge_request.iid}/blockees", maintainer)

      aggregate_failures('response') do
        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
      end

      aggregate_failures('json_response') do
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(other_merge_request.blocks_as_blocker.size)
        expect(json_response.first['id']).to eq(block_1.id)
        expect(json_response.first.dig('blocking_merge_request', 'id'))
          .to eq(block_1.blocking_merge_request.id)
        expect(json_response.first.dig('blocked_merge_request', 'id'))
          .to eq(block_1.blocked_merge_request.id)
        expect(json_response.find { |block| block['id'] == block_1.id }).to include('blocked_merge_request')
        expect(json_response.find { |block| block['id'] == private_block_1.id }).not_to include('blocked_merge_request')
        expect(json_response.find { |block| block['id'] == private_block_2.id }).not_to include('blocked_merge_request')
      end
    end

    it 'returns a 404 when merge_request_iid not found' do
      get api("/projects/#{project.id}/merge_requests/0/blockees", maintainer)
      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when merge request author has only guest access' do
      it_behaves_like 'rejects user from accessing merge request info' do
        let(:user) { guest }
        let(:url) { "/projects/#{project.id}/merge_requests/#{merge_request.iid}/blockees" }
      end
    end
  end
end
