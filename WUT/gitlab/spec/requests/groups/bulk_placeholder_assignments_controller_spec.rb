# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::BulkPlaceholderAssignmentsController, feature_category: :importers do
  include WorkhorseHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :public, owners: user) }
  let_it_be(:source_user) { create(:import_source_user, namespace: group) }
  let(:file) { fixture_file_upload('spec/fixtures/import/user_mapping/user_mapping_upload.csv') }

  describe 'GET /groups/*group_id/-/group_members/bulk_reassignment_file' do
    subject(:request) do
      get group_bulk_reassignment_file_path(group_id: group)
    end

    context 'when not signed in' do
      it 'forbids access to the endpoint' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when signed in' do
      before do
        sign_in(user)
      end

      it 'responds with CSV data' do
        request

        expect(response).to have_gitlab_http_status(:success)
      end

      context 'and the user is not a group owner' do
        let_it_be(:group) { create(:group, :public) }

        it 'forbids access to the endpoint' do
          request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'and the CSV is not generated properly' do
        before do
          allow_next_instance_of(Import::SourceUsers::GenerateCsvService) do |service|
            allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'my error message'))
          end
        end

        it 'redirects with an error' do
          request

          expect(response).to be_redirect
          expect(flash[:alert]).to eq('my error message')
        end
      end
    end
  end

  describe 'POST /groups/*group_id/-/group_members/bulk_reassignment_file' do
    let(:file) { fixture_file_upload('spec/fixtures/import/user_mapping/user_mapping_upload.csv') }

    subject(:request) do
      workhorse_post_with_file(
        group_bulk_reassignment_file_path(group_id: group, format: :json),
        file_key: :file,
        params: { file: file }
      )
    end

    context 'when signed in' do
      before do
        sign_in(user)
      end

      it 'executes the csv reassignment service' do
        expect_next_instance_of(Import::SourceUsers::BulkReassignFromCsvService) do |service|
          expect(service).to receive(:async_execute).and_call_original
        end

        request
      end

      it 'responds with success' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'and the user is not a group owner' do
        let_it_be(:group) { create(:group, :public) }

        it 'forbids access to the endpoint' do
          request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'and the file is not a CSV' do
        let(:file) { fixture_file_upload('spec/fixtures/dk.png') }

        it 'returns unprocessable_entity' do
          request

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response).to eq({
            'message' => s_('UserMapping|You must upload a CSV file with a .csv file extension.')
          })
        end
      end

      context 'and the file contents are invalid' do
        before do
          expect_next_instance_of(::Import::UserMapping::ReassignmentCsvValidator) do |service|
            allow(service).to receive(:errors).and_return(['This is wrong.', 'That is wrong.'])
          end
        end

        it 'returns unprocessable_entity' do
          request

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response).to eq({
            'message' => 'The following errors are preventing the sheet from ' \
              'being processed: This is wrong. That is wrong.'
          })
        end
      end
    end

    context 'when not signed in' do
      it 'forbids access to the endpoint' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /groups/*group_id/-/group_members/bulk_reassignment_file/authorize' do
    include_context 'workhorse headers'

    subject(:request) do
      post authorize_group_bulk_reassignment_file_path(group_id: group, format: :json),
        params: { file: file },
        headers: workhorse_headers
    end

    before do
      sign_in(user)
    end

    it 'responds with success' do
      request

      expect(response).to have_gitlab_http_status(:ok)
    end
  end
end
