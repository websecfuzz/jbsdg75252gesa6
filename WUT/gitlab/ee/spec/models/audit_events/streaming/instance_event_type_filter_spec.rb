# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::InstanceEventTypeFilter, feature_category: :audit_events do
  subject(:event_type_filter) { build(:audit_events_streaming_instance_event_type_filter) }

  describe 'Associations' do
    it 'belongs to a instance external audit event destination' do
      expect(subject.instance_external_audit_event_destination).not_to be_nil
    end
  end

  describe 'Validations' do
    it { is_expected.to belong_to(:instance_external_audit_event_destination) }

    it {
      is_expected.to validate_uniqueness_of(:audit_event_type).scoped_to(:instance_external_audit_event_destination_id)
    }
  end

  it_behaves_like 'audit event streaming filter' do
    let(:factory_name) { "audit_events_streaming_instance_event_type_filter" }
  end
end
