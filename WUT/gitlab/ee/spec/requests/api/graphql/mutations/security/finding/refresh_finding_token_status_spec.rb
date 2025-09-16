# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Security::Finding::RefreshFindingTokenStatus, feature_category: :secret_detection do
  include GraphqlHelpers

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }
  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project) }
  let_it_be(:finding) { create(:vulnerabilities_finding, vulnerability: vulnerability) }

  describe '#resolve' do
    subject(:execute) { mutation.resolve(vulnerability_id: vulnerability.to_global_id) }

    before do
      stub_feature_flags(validity_checks: true)
      stub_feature_flags(secret_detection_validity_checks_refresh_token: true)
      stub_licensed_features(secret_detection_validity_checks: true)
      project.security_setting.update!(validity_checks_enabled: true)
    end

    context 'when a user is not logged in' do
      let(:current_user) { nil }

      it 'raises an error' do
        expect { execute }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the current user does not have access to the project' do
      let_it_be(:current_user) { create(:user) }

      it 'raises an error' do
        expect { execute }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the current user has access to the project' do
      let_it_be(:current_user) { create(:user) }

      before_all do
        project.add_developer(current_user)
      end

      context 'when the secret_detection_validity_checks FF is disabled' do
        before do
          stub_feature_flags(secret_detection_validity_checks_refresh_token: false)
        end

        it 'raises ResourceNotAvailable' do
          expect { execute }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the vulnerability does not exist' do
        let(:fake_gid) do
          Vulnerability.new(id: non_existing_record_id).to_global_id
        end

        it 'raises ResourceNotAvailable' do
          expect do
            mutation.resolve(vulnerability_id: fake_gid)
          end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when validity checks is not enabled for the project' do
        before do
          project.security_setting.update!(validity_checks_enabled: false)
        end

        it 'raises an error' do
          expect { execute }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the vulnerability has no finding' do
        let_it_be(:vulnerability_without_finding) { create(:vulnerability, project: project) }
        let_it_be(:gid) { vulnerability_without_finding.to_global_id }

        it 'raises an error' do
          expect do
            mutation.resolve(vulnerability_id: gid)
          end.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the vulnerability has a finding' do
        let(:mock_service) { instance_double(Security::SecretDetection::UpdateTokenStatusService) }
        let_it_be(:token_status) { create(:finding_token_status, finding: finding, project: project, status: 'active') }

        before do
          project.security_setting.reload.update!(validity_checks_enabled: true)
          allow(Security::SecretDetection::UpdateTokenStatusService).to receive(:new).and_return(mock_service)
          allow(mock_service).to receive(:execute_for_finding)
          allow(Vulnerabilities::FindingTokenStatus).to receive(:find).with(finding.id).and_return(token_status)
        end

        it 'calls the update service and returns the token status' do
          result = execute

          expect(Security::SecretDetection::UpdateTokenStatusService).to have_received(:new)
          expect(mock_service).to have_received(:execute_for_finding).with(finding.id)
          expect(result[:errors]).to be_empty
          expect(result[:finding_token_status]).to eq(token_status)
        end

        it 'returns a valid response structure' do
          result = execute

          expect(result).to have_key(:errors)
          expect(result).to have_key(:finding_token_status)
          expect(result[:errors]).to be_an(Array)
        end

        context 'when no token status record was created' do
          let(:other_vulnerability) { create(:vulnerability, project: project) }
          let!(:other_finding) { create(:vulnerabilities_finding, vulnerability: other_vulnerability) }

          subject(:execute) { mutation.resolve(vulnerability_id: other_vulnerability.to_global_id) }

          it 'returns status not found message' do
            result = execute

            expect(other_finding.finding_token_status).to be_nil
            expect(result[:errors]).to be_empty
            expect(result[:finding_token_status])
              .to eq("Token status not found for finding #{other_finding.id}")
          end
        end
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(validity_checks: false)
        end

        it 'raises an error' do
          expect { execute }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when the current user does not have the required permission' do
      let_it_be(:current_user) { create(:user) }

      before_all do
        project.add_guest(current_user)
      end

      it 'raises an error' do
        expect { execute }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end
  end

  describe 'authorization' do
    it 'requires update_secret_detection_validity_checks_status permission' do
      expect(described_class).to require_graphql_authorizations(:update_secret_detection_validity_checks_status)
    end
  end
end
