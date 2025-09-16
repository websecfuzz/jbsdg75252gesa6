# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an instance audit event type filter', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be(:destination) { create(:audit_events_instance_external_streaming_destination) }
  let_it_be(:event_type_filter) do
    create(:audit_events_instance_event_type_filters, external_streaming_destination: destination,
      audit_event_type: 'event_type_filters_created')
  end

  let_it_be(:mutation_name) { :audit_events_instance_destination_events_add }
  let(:mutation) { graphql_mutation(mutation_name, input) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }
  let_it_be(:input) { { destinationId: destination.to_gid, eventTypeFilters: ['event_type_filters_deleted'] } }

  subject { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when current user is instance admin' do
    let(:current_user) { create(:admin) }

    include_examples 'create event type filters for external audit event destinations' do
      let_it_be(:non_existing_destination_id) do
        "gid://gitlab/AuditEvents::Instance::ExternalStreamingDestination/#{non_existing_record_id}"
      end
    end
  end

  context 'when current user is not instance admin' do
    before do
      stub_licensed_features(external_audit_events: true)
    end

    let_it_be(:current_user) { create(:user) }

    it_behaves_like 'a mutation on an unauthorized resource'
  end
end
