# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Applications::CreateService, feature_category: :system_access do
  include TestRequestHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }

  let(:group) { create(:group) }
  let(:params) { attributes_for(:application, scopes: %w[read_user]) }

  subject(:service) { described_class.new(user, params) }

  describe '#audit_oauth_application_creation' do
    where(:case_name, :owner, :entity_type) do
      'instance application' | nil         | 'User'
      'group application'    | ref(:group) | 'Group'
      'user application'     | ref(:user)  | 'User'
    end

    with_them do
      before do
        stub_licensed_features(extended_audit_events: true)
        params[:owner] = owner
      end

      it 'creates audit event with correct parameters' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          name: 'oauth_application_created',
          author: user,
          scope: owner || user,
          target: instance_of(::Doorkeeper::Application),
          message: 'OAuth application added',
          additional_details: hash_including(
            application_name: anything,
            application_id: anything,
            scopes: %w[read_user]
          ),
          ip_address: test_request.remote_ip
        )

        service.execute(test_request)
      end

      it 'creates AuditEvent with correct entity type' do
        expect { service.execute(test_request) }.to change(AuditEvent, :count).by(1)
        expect(AuditEvent.last.entity_type).to eq(entity_type)
      end
    end

    context 'when application has multiple scopes' do
      let(:params) { attributes_for(:application, scopes: %w[api read_user read_repository]) }

      it 'includes all scopes in audit details' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            additional_details: hash_including(
              scopes: %w[api read_user read_repository]
            )
          )
        )

        service.execute(test_request)
      end
    end
  end

  context 'for ROPC' do
    where(:saas_feature_available, :feature_enabled, :ropc_enabled) do
      false | false | true
      false | true  | true
      true  | false | true
      true  | true  | false
    end

    with_them do
      before do
        stub_saas_features(disable_ropc_for_new_applications: saas_feature_available)
        stub_feature_flags(disable_ropc_for_new_applications: feature_enabled)
      end

      it 'sets ropc_enabled? correctly' do
        expect(service.execute(test_request).ropc_enabled?).to eq(ropc_enabled)
      end
    end
  end
end
