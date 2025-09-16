# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretPushProtection::ResponseHandler, feature_category: :secret_detection do
  include_context 'secrets check context'

  subject(:response_handler) do
    described_class.new(
      project: project,
      changes_access: changes_access
    )
  end

  describe '#format_response' do
    context 'when response status is NOT_FOUND' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::NOT_FOUND,
          results: []
        )
      end

      it 'logs secrets not found message and does not raise error' do
        expect { response_handler.format_response(response) }.not_to raise_error

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:secrets_not_found],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'when response status is FOUND' do
      let(:finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          new_blob_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab personal access token"
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND,
          results: [finding]
        )
      end

      before do
        allow(::Gitlab::Git::Tree).to receive(:tree_entries)
          .and_return([tree_entries, gitaly_pagination_cursor])
      end

      it 'raises ForbiddenError with findings details and logs found secrets' do
        expect { response_handler.format_response(response) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include(log_messages[:found_secrets])
            expect(error.message).to include(log_messages[:found_secrets_post_message])
            expect(error.message).to include(log_messages[:skip_secret_detection])
            expect(error.message).to include(".env")
            expect(error.message).to include("GitLab personal access token")
          end

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:found_secrets],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end

      it 'tracks findings in audit logger' do
        audit_logger = instance_double(Gitlab::Checks::SecretPushProtection::AuditLogger)
        allow(response_handler).to receive(:audit_logger).and_return(audit_logger)
        expect(audit_logger).to receive(:track_secret_found).with("GitLab personal access token")

        expect { response_handler.format_response(response) }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
      end

      context 'when the path matches exclusion patterns' do
        before do
          exclusions_manager = instance_double(Gitlab::Checks::SecretPushProtection::ExclusionsManager)
          allow(response_handler).to receive(:exclusions_manager).and_return(exclusions_manager)
          allow(exclusions_manager).to receive(:matches_excluded_path?).and_return(true)
        end

        it 'changes the status to NOT_FOUND and does not raise error' do
          expect { response_handler.format_response(response) }.not_to raise_error

          expect(logged_messages[:info]).to include(
            hash_including(
              "message" => log_messages[:secrets_not_found],
              "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
            )
          )
        end
      end

      context 'when no tree entries are found' do
        before do
          allow(::Gitlab::Git::Tree).to receive(:tree_entries)
            .and_return([[], gitaly_pagination_cursor])
        end

        it 'raises ForbiddenError with blob findings information' do
          expect { response_handler.format_response(response) }
            .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
              expect(error.message).to include("Secret leaked in blob: #{new_blob_reference}")
              expect(error.message).to include("line:1 | GitLab personal access token")
            end
        end
      end
    end

    context 'when response status is FOUND_WITH_ERRORS' do
      let(:finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          new_blob_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab personal access token"
        )
      end

      let(:error_finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          "some_error_blob",
          ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS,
          results: [finding, error_finding]
        )
      end

      before do
        allow(::Gitlab::Git::Tree).to receive(:tree_entries)
          .and_return([tree_entries, gitaly_pagination_cursor])
      end

      it 'raises ForbiddenError with errors message and logs found secrets with errors' do
        expect { response_handler.format_response(response) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include(log_messages[:found_secrets_with_errors])
            expect(error.message).to include(log_messages[:found_secrets_post_message])
            expect(error.message).to include("Failed to scan blob(id: some_error_blob) due to regex error.")
          end

        expect(logged_messages[:info]).to include(
          hash_including(
            "message" => log_messages[:found_secrets_with_errors],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'when response has timeout findings' do
      let(:timeout_finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          "some_timeout_blob",
          ::Gitlab::SecretDetection::Core::Status::PAYLOAD_TIMEOUT
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS,
          results: [timeout_finding]
        )
      end

      before do
        allow(::Gitlab::Git::Tree).to receive(:tree_entries)
          .and_return([[], gitaly_pagination_cursor])
      end

      it 'includes timeout error messages in the error details' do
        expect { response_handler.format_response(response) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include(format(error_messages[:blob_timed_out_error],
              payload_id: "some_timeout_blob"))
          end
      end
    end

    context 'when response status is SCAN_TIMEOUT' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::SCAN_TIMEOUT,
          results: []
        )
      end

      it 'logs scan timeout error and does not raise error' do
        expect { response_handler.format_response(response) }.not_to raise_error

        expect(logged_messages[:error]).to include(
          hash_including(
            "message" => error_messages[:scan_timeout_error],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'when response status is INPUT_ERROR' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::INPUT_ERROR,
          results: []
        )
      end

      it 'logs invalid input error and does not raise error' do
        expect { response_handler.format_response(response) }.not_to raise_error

        expect(logged_messages[:error]).to include(
          hash_including(
            "message" => error_messages[:invalid_input_error],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'when response status is unknown' do
      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: -1,
          results: []
        )
      end

      it 'logs invalid scan status code error and does not raise error' do
        expect { response_handler.format_response(response) }.not_to raise_error

        expect(logged_messages[:error]).to include(
          hash_including(
            "message" => error_messages[:invalid_scan_status_code_error],
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'when too many tree entries exist' do
      let(:finding) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          new_blob_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          'desc1',
          'desc1'
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND,
          results: [finding]
        )
      end

      before do
        cursor = Gitaly::PaginationCursor.new(next_cursor: 'abc')
        allow(::Gitlab::Git::Tree).to receive(:tree_entries)
          .and_return([tree_entries, cursor])
      end

      it 'logs a pagination warning but still processes the findings' do
        expect { response_handler.format_response(response) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError)

        expect(logged_messages[:error]).to include(
          hash_including(
            "message" => too_many_tree_entries_error,
            "class" => "Gitlab::Checks::SecretPushProtection::ResponseHandler"
          )
        )
      end
    end

    context 'when multiple findings map to the same commit in different files' do
      let(:finding1) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          new_blob_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          1,
          'desc1',
          'desc1'
        )
      end

      let(:finding2) do
        ::Gitlab::SecretDetection::Core::Finding.new(
          new_blob_reference,
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          2,
          'desc2',
          'desc2'
        )
      end

      let(:response) do
        ::Gitlab::SecretDetection::Core::Response.new(
          status: ::Gitlab::SecretDetection::Core::Status::FOUND,
          results: [finding1, finding2]
        )
      end

      before do
        allow(response_handler).to receive(:commits).and_return([new_commit])

        cursor = Gitaly::PaginationCursor.new(next_cursor: '')

        entry1 = Gitlab::Git::Tree.new(
          id: new_blob_reference,
          type: :blob,
          mode: '100644',
          name: '.env',
          path: '.env',
          flat_path: '.env',
          commit_id: new_commit
        )

        entry2 = Gitlab::Git::Tree.new(
          id: new_blob_reference,
          type: :blob,
          mode: '100644',
          name: 'config.yml',
          path: 'config.yml',
          flat_path: 'config.yml',
          commit_id: new_commit
        )

        allow(::Gitlab::Git::Tree)
          .to receive(:tree_entries)
          .with(repository: repository, sha: new_commit, recursive: true, rescue_not_found: false)
          .and_return([[entry1, entry2], cursor])
      end

      it 'includes findings from all affected files in the error message' do
        expect { response_handler.format_response(response) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError) do |error|
            expect(error.message).to include('.env')
            expect(error.message).to include('config.yml')
            expect(error.message).to include('desc1')
            expect(error.message).to include('desc2')
          end
      end
    end
  end
end
