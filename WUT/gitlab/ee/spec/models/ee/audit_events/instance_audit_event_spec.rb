# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::AuditEvents::InstanceAuditEvent, type: :model, feature_category: :audit_events do
  describe '#entity' do
    let_it_be(:instance_audit_event) { create(:audit_events_instance_audit_event) }

    it 'returns an instance scope' do
      expect(instance_audit_event.entity).to be_an_instance_of(::Gitlab::Audit::InstanceScope)
    end
  end

  describe '#entity_type' do
    let_it_be(:instance_audit_event) { create(:audit_events_instance_audit_event) }

    it 'returns InstanceScope' do
      expect(instance_audit_event.entity_type).to eq(::Gitlab::Audit::InstanceScope.name)
    end
  end

  describe '#present' do
    let_it_be(:instance_audit_event) { create(:audit_events_instance_audit_event) }

    it 'returns a presenter' do
      expect(instance_audit_event.present).to be_an_instance_of(AuditEventPresenter)
    end
  end

  it_behaves_like 'streaming audit event model'
end
