# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Destroy Google Cloud logging configuration', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:config) { create(:google_cloud_logging_configuration) }
  let_it_be(:group) { config.group }
  let_it_be(:owner) { create(:user) }

  let(:current_user) { owner }
  let(:mutation) { graphql_mutation(:google_cloud_logging_configuration_destroy, id: global_id_of(config)) }
  let(:mutation_response) { graphql_mutation_response(:google_cloud_logging_configuration_destroy) }

  subject(:mutate) { post_graphql_mutation(mutation, current_user: owner) }

  shared_examples 'a mutation that does not destroy a configuration' do
    it 'does not destroy the configuration' do
      expect { mutate }
        .not_to change { AuditEvents::GoogleCloudLoggingConfiguration.count }
    end

    it 'does not create audit event' do
      expect { mutate }.not_to change { AuditEvent.count }
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is a group owner' do
      before do
        group.add_owner(owner)
        allow(Gitlab::Audit::Auditor).to receive(:audit)
      end

      it 'destroys the configuration' do
        expect { mutate }
          .to change { AuditEvents::GoogleCloudLoggingConfiguration.count }.by(-1)
      end

      it 'audits the deletion' do
        subject

        expect(Gitlab::Audit::Auditor).to have_received(:audit) do |args|
          expect(args[:name]).to eq('google_cloud_logging_configuration_deleted')
          expect(args[:author]).to eq(current_user)
          expect(args[:scope]).to eq(group)
          expect(args[:target]).to eq(group)
          expect(args[:message]).to eq("Deleted Google Cloud logging configuration with name: #{config.name} " \
                                       "project id: #{config.google_project_id_name} and log id: #{config.log_id_name}")
        end
      end

      context 'when there is an error during destroy' do
        before do
          allow_next_instance_of(Mutations::AuditEvents::GoogleCloudLoggingConfigurations::Destroy) do |mutation|
            allow(mutation).to receive(:authorized_find!).and_return(config)
          end

          allow(config).to receive(:destroy).and_return(false)

          errors = ActiveModel::Errors.new(config).tap { |e| e.add(:base, 'error message') }
          allow(config).to receive(:errors).and_return(errors)
        end

        it 'does not destroy the configuration and returns the error' do
          expect { mutate }
            .not_to change { AuditEvents::GoogleCloudLoggingConfiguration.count }

          expect(mutation_response).to include(
            'errors' => ['error message']
          )
        end
      end

      context 'when paired destination exists' do
        let(:paired_model) do
          create(:audit_events_group_external_streaming_destination, :gcp, legacy_destination_ref: config.id)
        end

        it_behaves_like 'deletes paired destination', :config
      end
    end

    context 'when current user is a group maintainer' do
      before do
        group.add_maintainer(owner)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not destroy a configuration'
    end

    context 'when current user is a group developer' do
      before do
        group.add_developer(owner)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not destroy a configuration'
    end

    context 'when current user is a group guest' do
      before do
        group.add_guest(owner)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not destroy a configuration'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
    it_behaves_like 'a mutation that does not destroy a configuration'
  end
end
