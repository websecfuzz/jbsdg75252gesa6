# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::CreateBlockService, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:private_project) { create(:project, :repository, :private) }
  let_it_be_with_refind(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be_with_refind(:blocking_merge_request) do
    create(:merge_request, :unique_branches, source_project: project, target_project: project)
  end

  let(:service) do
    described_class.new(user: user, merge_request: merge_request, blocking_merge_request_id:
                                      blocking_merge_request_id)
  end

  let(:blocking_merge_request_id) { blocking_merge_request.id }
  let(:user) { merge_request.author }
  let(:result) { service.execute }

  describe '#execute' do
    it 'creates a block' do
      expect { result }.to change { MergeRequestBlock.count }.by(1)

      expect(result).to be_success
      expect(result.payload[:merge_request_block]).to have_attributes(
        blocking_merge_request_id: blocking_merge_request_id, blocked_merge_request_id: merge_request.id)
    end

    context 'when the blocking mr is not found' do
      let(:blocking_merge_request_id) { non_existing_record_id }

      it 'returns a service error with not found' do
        expect { result }.not_to change { MergeRequestBlock.count }

        expect(result).to be_error
        expect(result).to have_attributes(message: 'Blocking merge request not found', reason: :not_found)
      end
    end

    context 'when the user lacks permissions for the blocking mr' do
      let!(:blocking_merge_request) do
        create(:merge_request, :unique_branches, source_project: private_project, target_project: private_project)
      end

      it 'returns a service error with forbidden' do
        expect { result }.not_to change { MergeRequestBlock.count }

        expect(result).to be_error
        expect(result).to have_attributes(message: 'Lacking permissions to the blocking merge request',
          reason: :forbidden)
      end
    end

    context 'when the user lacks permissions for merge request' do
      let!(:blocking_merge_request) do
        create(:merge_request, :unique_branches, source_project: private_project, target_project: private_project)
      end

      let(:user) { create(:user) }

      it 'returns a service error with forbidden' do
        expect { result }.not_to change { MergeRequestBlock.count }

        expect(result).to be_error
        expect(result).to have_attributes(message: 'Lacking permissions to update the merge request',
          reason: :forbidden)
      end
    end

    context 'when the block already exists' do
      before do
        ::MergeRequestBlock.create!(
          blocking_merge_request_id: blocking_merge_request_id,
          blocked_merge_request_id: merge_request.id
        )
      end

      it 'returns a service error with conflict' do
        expect { result }.not_to change { MergeRequestBlock.count }

        expect(result).to be_error
        expect(result).to have_attributes(message: 'Block already exists', reason: :conflict)
      end
    end

    context 'when the block fails to save' do
      let(:blocking_merge_request_id) { merge_request.id }

      it 'returns a service error with bad request' do
        expect { result }.not_to change { MergeRequestBlock.count }

        expect(result).to be_error
        expect(result).to have_attributes(message: 'This block is self-referential', reason: :bad_request)
      end
    end
  end
end
