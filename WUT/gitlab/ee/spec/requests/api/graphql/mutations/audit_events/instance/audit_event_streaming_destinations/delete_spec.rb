# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete instance level external audit event streaming destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:destination) { create(:audit_events_instance_external_streaming_destination) }
  let_it_be(:current_user) { create(:admin) }

  let(:mutation) do
    graphql_mutation(:instance_audit_event_streaming_destinations_delete, id: global_id_of(destination))
  end

  let(:mutation_response) { graphql_mutation_response(:instance_audit_event_streaming_destinations_delete) }

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    context 'when current user is admin' do
      it 'destroys the configuration' do
        expect { mutate }.to change { AuditEvents::Instance::ExternalStreamingDestination.count }.by(-1)
      end

      it 'audits the deletion' do
        expected_hash = {
          name: 'deleted_instance_audit_event_streaming_destination',
          author: current_user,
          scope: an_instance_of(Gitlab::Audit::InstanceScope),
          target: destination,
          message: 'Deleted audit event streaming destination for HTTP',
          additional_details: {
            id: destination.id,
            category: destination.category
          }
        }

        expect(Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_hash))

        mutate
      end

      context 'when there is an error during destroy' do
        before do
          expect_next_found_instance_of(AuditEvents::Instance::ExternalStreamingDestination) do |destination|
            allow(destination).to receive(:destroy).and_return(false)
            errors = ActiveModel::Errors.new(destination).tap { |e| e.add(:base, 'error message') }
            allow(destination).to receive(:errors).and_return(errors)
          end
        end

        it 'does not destroy the configuration and returns the error' do
          expect { mutate }.not_to change { AuditEvents::Instance::ExternalStreamingDestination.count }

          expect(mutation_response).to include('errors' => ['error message'])
        end
      end

      context 'when paired destination exists' do
        let(:paired_model) do
          create(:instance_external_audit_event_destination, stream_destination_id: destination.id)
        end

        it_behaves_like 'deletes paired destination', :destination
      end
    end

    context 'when current user is not admin' do
      let_it_be(:current_user) { create(:user) }

      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end
end
